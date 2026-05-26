import ArgumentParser
import Foundation

enum BattSailError: Error, CustomStringConvertible {
    case validation(String)
    case shell(String)
    case permission(String)

    var description: String {
        switch self {
        case .validation(let m), .shell(let m), .permission(let m):
            return m
        }
    }
}

struct Shell {
    @discardableResult
    static func run(_ launchPath: String, _ args: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()
        let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw BattSailError.shell("Command failed: \(launchPath) \(args.joined(separator: " "))\n\(err)")
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct BatteryInfo {
    let percentage: Int
    let isCharging: Bool
}

enum ActiveMode: String, Codable { case desktop, cycle, custom }

struct AppConfig: Codable {
    var mode: ActiveMode
    var minLimit: Int
    var maxLimit: Int
    var scheduleTime: String?
    var scheduleDays: String?
    var scheduleTarget: Int?

    static let sharedPath = "/Library/Application Support/batt-sail/config.json"
}

struct HardwareBridge {
    static var isAppleSilicon: Bool { ProcessInfo.processInfo.machineHardwareName == "arm64" || ProcessInfo.processInfo.machineHardwareName == "arm64e" }

    static func readBatteryInfo() throws -> BatteryInfo {
        let out = try Shell.run("/usr/bin/pmset", ["-g", "batt"])
        guard let line = out.split(separator: "\n").first(where: { $0.contains("%") }) else {
            throw BattSailError.shell("Unable to parse battery state")
        }
        let regex = try NSRegularExpression(pattern: "(\\d+)%")
        let text = String(line)
        guard let m = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let r = Range(m.range(at: 1), in: text),
              let pct = Int(text[r]) else {
            throw BattSailError.shell("Battery percentage parse error")
        }
        return BatteryInfo(percentage: pct, isCharging: text.localizedCaseInsensitiveContains("charging"))
    }

    static func readCurrentLimit() throws -> Int {
        if isAppleSilicon {
            let out = try Shell.run("/usr/local/bin/smc", ["-k", "CHWA", "-r"])
            if let n = Int(out.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) { return n }
        }
        let out = try Shell.run("/usr/local/bin/smc", ["-k", "BCLM", "-r"])
        if let n = Int(out.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()) { return n }
        throw BattSailError.shell("Could not read current SMC limit")
    }

    static func writeChargeLimit(_ percent: Int) throws {
        guard (50...100).contains(percent) else {
            throw BattSailError.validation("Limit must be within 50...100")
        }
        let current = try readCurrentLimit()
        if current == percent { return }

        // Intel/T2: BCLM key. Apple Silicon: CHWA is common in open-source smc wrappers.
        if isAppleSilicon {
            _ = try Shell.run("/usr/local/bin/smc", ["-k", "CHWA", "-w", String(percent)])
        } else {
            _ = try Shell.run("/usr/local/bin/smc", ["-k", "BCLM", "-w", String(percent)])
        }
    }
}

extension ProcessInfo {
    var machineHardwareName: String {
        var size: size_t = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}

struct ConfigStore {
    static func save(_ config: AppConfig) throws {
        let path = AppConfig.sharedPath
        let dir = URL(fileURLWithPath: path).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(config)
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
    }

    static func load() throws -> AppConfig {
        let data = try Data(contentsOf: URL(fileURLWithPath: AppConfig.sharedPath))
        return try JSONDecoder().decode(AppConfig.self, from: data)
    }
}

struct HysteresisEngine {
    static func enforce(min: Int, max: Int) throws {
        guard min < max else { throw BattSailError.validation("min must be less than max") }
        let info = try HardwareBridge.readBatteryInfo()
        if info.percentage >= max {
            try HardwareBridge.writeChargeLimit(min)
        } else if info.percentage <= min {
            try HardwareBridge.writeChargeLimit(100)
        }
    }
}

struct Daemon {
    static let label = "com.battsail.daemon"
    static let plistPath = "/Library/LaunchDaemons/\(label).plist"

    static func install(binaryPath: String = "/usr/local/bin/batt-sail") throws {
        let plist = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>\(label)</string>
    <key>ProgramArguments</key>
    <array>
        <string>\(binaryPath)</string>
        <string>enforce</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>StandardOutPath</key>
    <string>/var/log/batt-sail.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/batt-sail.err.log</string>
</dict>
</plist>
"""
        try plist.write(toFile: plistPath, atomically: true, encoding: .utf8)
        _ = try Shell.run("/bin/launchctl", ["bootstrap", "system", plistPath])
    }

    static func start() throws { _ = try Shell.run("/bin/launchctl", ["kickstart", "-k", "system/\(label)"]) }
    static func stop() throws { _ = try Shell.run("/bin/launchctl", ["bootout", "system", plistPath]) }

    static func isLoaded() -> Bool {
        (try? Shell.run("/bin/launchctl", ["print", "system/\(label)"])) != nil
    }
}

struct Scheduler {
    static func store(time: String, days: String, target: Int) throws {
        var c = try ConfigStore.load()
        c.scheduleTime = time
        c.scheduleDays = days
        c.scheduleTarget = target
        try ConfigStore.save(c)
    }

    static func maybePrimeForNextEvent() throws {
        let c = try ConfigStore.load()
        guard let t = c.scheduleTime, let target = c.scheduleTarget else { return }
        let leadMins = 120
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        guard let eventTime = fmt.date(from: t) else { return }
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.hour,.minute], from: eventTime)
        guard let todayEvent = cal.date(bySettingHour: comps.hour ?? 0, minute: comps.minute ?? 0, second: 0, of: now) else { return }
        let trigger = todayEvent.addingTimeInterval(Double(-leadMins * 60))
        if now >= trigger && now <= todayEvent {
            try HardwareBridge.writeChargeLimit(target)
        }
    }
}

struct BattSail: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "batt-sail",
        abstract: "Battery sailing and charge limit manager for macOS",
        subcommands: [Preset.self, Custom.self, Schedule.self, DaemonCmd.self, Status.self, Enforce.self]
    )
}

struct Preset: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Apply a preset sailing profile")
    @Argument(help: "desktop or cycle") var type: String

    mutating func run() throws {
        let cfg: AppConfig
        switch type {
        case "desktop": cfg = AppConfig(mode: .desktop, minLimit: 50, maxLimit: 55)
        case "cycle": cfg = AppConfig(mode: .cycle, minLimit: 60, maxLimit: 80)
        default: throw BattSailError.validation("Unknown preset: \(type)")
        }
        try ConfigStore.save(cfg)
        try HysteresisEngine.enforce(min: cfg.minLimit, max: cfg.maxLimit)
        print("Applied \(type) preset (\(cfg.minLimit)-\(cfg.maxLimit))")
    }
}

struct Custom: ParsableCommand {
    @Option(name: .long) var max: Int
    @Option(name: .long) var min: Int
    mutating func run() throws {
        guard min >= 50, max <= 100, min < max else { throw BattSailError.validation("Invalid limits") }
        let cfg = AppConfig(mode: .custom, minLimit: min, maxLimit: max)
        try ConfigStore.save(cfg)
        try HysteresisEngine.enforce(min: min, max: max)
        print("Applied custom sailing band \(min)-\(max)")
    }
}

struct Schedule: ParsableCommand {
    @Option(name: .long) var time: String
    @Option(name: .long) var days: String
    @Option(name: .long) var target: Int
    mutating func run() throws {
        guard (50...100).contains(target) else { throw BattSailError.validation("target must be 50...100") }
        try Scheduler.store(time: time, days: days, target: target)
        print("Scheduled top-up to \(target)% at \(time) on \(days)")
    }
}

struct DaemonCmd: ParsableCommand {
    @Argument var action: String
    mutating func run() throws {
        switch action {
        case "install": try Daemon.install(); print("Daemon installed")
        case "start": try Daemon.start(); print("Daemon started")
        case "stop": try Daemon.stop(); print("Daemon stopped")
        default: throw BattSailError.validation("action must be install|start|stop")
        }
    }
}

struct Enforce: ParsableCommand {
    mutating func run() throws {
        let cfg = try ConfigStore.load()
        try Scheduler.maybePrimeForNextEvent()
        try HysteresisEngine.enforce(min: cfg.minLimit, max: cfg.maxLimit)
    }
}

struct Status: ParsableCommand {
    mutating func run() throws {
        let cfg = try ConfigStore.load()
        let batt = try HardwareBridge.readBatteryInfo()
        let limit = try HardwareBridge.readCurrentLimit()
        print("Battery: \(batt.percentage)%")
        print("Current Limit: \(limit)%")
        print("Daemon: \(Daemon.isLoaded() ? "running" : "not running")")
        print("Mode: \(cfg.mode.rawValue) (min=\(cfg.minLimit), max=\(cfg.maxLimit))")
        print("Next Schedule: \(cfg.scheduleTime ?? "none") days=\(cfg.scheduleDays ?? "none") target=\(cfg.scheduleTarget.map(String.init) ?? "none")")
    }
}

BattSail.main()
