import ArgumentParser
import Foundation

// MARK: - Errors

enum BattSailError: Error, CustomStringConvertible {
    case validation(String)
    case shell(String)
    case permission(String)
    case backend(String)

    var description: String {
        switch self {
        case .validation(let message),
             .shell(let message),
             .permission(let message),
             .backend(let message):
            return message
        }
    }
}

// MARK: - Shell helper

struct Shell {
    struct Result {
        let stdout: String
        let stderr: String
        let exitCode: Int32
    }

    @discardableResult
    static func run(_ launchPath: String, _ args: [String]) throws -> String {
        let result = try capture(launchPath, args)
        if result.exitCode != 0 {
            throw BattSailError.shell(
                "Command failed: \(launchPath) \(args.joined(separator: " "))\n\(result.stderr)"
            )
        }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func capture(_ launchPath: String, _ args: [String]) throws -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = args
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        let outData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errData = stderr.fileHandleForReading.readDataToEndOfFile()
        return Result(
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }
}

// MARK: - Platform helpers

extension ProcessInfo {
    var machineHardwareName: String {
        var size: size_t = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }
}

// MARK: - Battery

struct BatteryInfo {
    let percentage: Int
    let state: String

    var isCharging: Bool {
        state.localizedCaseInsensitiveContains("charging") &&
            !state.localizedCaseInsensitiveContains("not charging")
    }
}

// MARK: - Config

enum ActiveMode: String, Codable {
    case desktop
    case cycle
    case custom
}

struct AppConfig: Codable {
    var mode: ActiveMode
    var minPercent: Int
    var maxPercent: Int
    var intelDisplayCompensation: Int

    static let sharedPath = "/Library/Application Support/batt-sail/config.json"
    static let defaultConfig = AppConfig(
        mode: .desktop,
        minPercent: 70,
        maxPercent: 80,
        intelDisplayCompensation: 3
    )

    enum CodingKeys: String, CodingKey {
        case mode
        case minPercent
        case maxPercent
        case minLimit
        case maxLimit
        case intelDisplayCompensation
        case compensateIntelOffset
    }

    init(mode: ActiveMode, minPercent: Int, maxPercent: Int, intelDisplayCompensation: Int) {
        self.mode = mode
        self.minPercent = minPercent
        self.maxPercent = maxPercent
        self.intelDisplayCompensation = intelDisplayCompensation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decodeIfPresent(ActiveMode.self, forKey: .mode) ?? .custom
        minPercent = try container.decodeIfPresent(Int.self, forKey: .minPercent) ??
            container.decodeIfPresent(Int.self, forKey: .minLimit) ??
            AppConfig.defaultConfig.minPercent
        maxPercent = try container.decodeIfPresent(Int.self, forKey: .maxPercent) ??
            container.decodeIfPresent(Int.self, forKey: .maxLimit) ??
            AppConfig.defaultConfig.maxPercent

        if let comp = try container.decodeIfPresent(Int.self, forKey: .intelDisplayCompensation) {
            intelDisplayCompensation = comp
        } else if let legacy = try container.decodeIfPresent(Bool.self, forKey: .compensateIntelOffset) {
            intelDisplayCompensation = legacy ? 3 : 0
        } else {
            intelDisplayCompensation = AppConfig.defaultConfig.intelDisplayCompensation
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(minPercent, forKey: .minPercent)
        try container.encode(maxPercent, forKey: .maxPercent)
        try container.encode(intelDisplayCompensation, forKey: .intelDisplayCompensation)
    }
}

struct ConfigStore {
    static func save(_ config: AppConfig) throws {
        try Validator.validateBand(
            min: config.minPercent,
            max: config.maxPercent,
            compensation: config.intelDisplayCompensation
        )
        let path = URL(fileURLWithPath: AppConfig.sharedPath)
        try FileManager.default.createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: path, options: .atomic)
    }

    static func load() throws -> AppConfig {
        let data = try Data(contentsOf: URL(fileURLWithPath: AppConfig.sharedPath))
        let config = try JSONDecoder().decode(AppConfig.self, from: data)
        try Validator.validateBand(
            min: config.minPercent,
            max: config.maxPercent,
            compensation: config.intelDisplayCompensation
        )
        return config
    }

    static func loadOrDefault() -> AppConfig {
        (try? load()) ?? AppConfig.defaultConfig
    }

    static var exists: Bool {
        FileManager.default.fileExists(atPath: AppConfig.sharedPath)
    }

    @discardableResult
    static func remove() throws -> Bool {
        let path = AppConfig.sharedPath
        guard FileManager.default.fileExists(atPath: path) else { return false }
        try FileManager.default.removeItem(atPath: path)
        return true
    }
}

// MARK: - Validation

enum Validator {
    static func validateBand(min: Int, max: Int, compensation: Int) throws {
        guard (40...99).contains(min) else {
            throw BattSailError.validation("min must be between 40 and 99.")
        }
        guard (41...100).contains(max) else {
            throw BattSailError.validation("max must be between 41 and 100.")
        }
        guard max > min else {
            throw BattSailError.validation("max must be greater than min.")
        }
        guard compensation >= 0 else {
            throw BattSailError.validation("intelDisplayCompensation must be >= 0.")
        }
        guard min - compensation >= 40 else {
            throw BattSailError.validation(
                "min - intelDisplayCompensation (\(min - compensation)) must be >= 40."
            )
        }
    }

    static func validateWriteLimit(_ percent: Int, backend: ChargeLimitBackend) throws {
        switch backend.kind {
        case .intelBCLM:
            guard (40...100).contains(percent) else {
                throw BattSailError.validation("Intel BCLM write limit must be between 40 and 100.")
            }
        case .appleSiliconCHWA:
            guard percent == 80 || percent == 100 else {
                throw BattSailError.validation("Apple Silicon CHWA only supports 80 or 100.")
            }
        case .unsupported:
            throw BattSailError.backend(backend.status)
        }
    }

    static func requireRoot() throws {
        guard getuid() == 0 else {
            throw BattSailError.permission("This operation requires sudo/root privileges.")
        }
    }
}

// MARK: - Backends

enum BackendKind: String {
    case intelBCLM = "Intel SMC BCLM"
    case appleSiliconCHWA = "Apple Silicon SMC CHWA"
    case unsupported = "Unsupported"
}

protocol ChargeLimitBackend {
    var kind: BackendKind { get }
    var keyName: String? { get }
    var status: String { get }
    func readChargeLimit() throws -> Int
    func writeChargeLimit(_ percent: Int) throws
}

extension ChargeLimitBackend {
    /// Writes only if the current limit differs from `percent`.
    /// Returns true when an SMC write occurred.
    func writeIfNeeded(_ percent: Int) throws -> Bool {
        try Validator.validateWriteLimit(percent, backend: self)
        try Validator.requireRoot()
        if let current = try? readChargeLimit(), current == percent {
            return false
        }
        try writeChargeLimit(percent)
        return true
    }
}

struct IntelBCLMBackend: ChargeLimitBackend {
    let kind: BackendKind = .intelBCLM
    let keyName: String? = "BCLM"
    let status = "available"

    func readChargeLimit() throws -> Int {
        try withSMC { smc in
            Int(try smc.readUInt8(key: "BCLM"))
        }
    }

    func writeChargeLimit(_ percent: Int) throws {
        try withSMC { smc in
            try smc.writeUInt8(key: "BCLM", value: UInt8(percent))
            // BFCL mirrors BCLM on some Intel machines; ignore if absent.
            do {
                try smc.writeUInt8(key: "BFCL", value: UInt8(percent))
            } catch SMCError.keyNotFound(_) {
                return
            }
        }
    }

    private func withSMC<T>(_ body: (SMC) throws -> T) throws -> T {
        let smc = SMC()
        try smc.open()
        defer { smc.close() }
        do {
            return try body(smc)
        } catch let error as SMCError {
            throw BattSailError.backend(error.description)
        }
    }
}

struct AppleSiliconCHWABackend: ChargeLimitBackend {
    let kind: BackendKind = .appleSiliconCHWA
    let keyName: String? = "CHWA"

    var status: String {
        "optional; only CHWA values 80 and 100 are supported"
    }

    func readChargeLimit() throws -> Int {
        try withSMC { smc in
            try smc.readUInt8(key: "CHWA") == 1 ? 80 : 100
        }
    }

    func writeChargeLimit(_ percent: Int) throws {
        try withSMC { smc in
            try smc.writeUInt8(key: "CHWA", value: percent == 80 ? 1 : 0)
        }
    }

    private func withSMC<T>(_ body: (SMC) throws -> T) throws -> T {
        let smc = SMC()
        try smc.open()
        defer { smc.close() }
        do {
            return try body(smc)
        } catch let error as SMCError {
            throw BattSailError.backend(error.description)
        }
    }
}

struct UnsupportedBackend: ChargeLimitBackend {
    let reason: String
    let kind: BackendKind = .unsupported
    let keyName: String? = nil
    var status: String { reason }

    func readChargeLimit() throws -> Int {
        throw BattSailError.backend(reason)
    }

    func writeChargeLimit(_ percent: Int) throws {
        throw BattSailError.backend(reason)
    }
}

enum BackendFactory {
    static var machine: String {
        ProcessInfo.processInfo.machineHardwareName
    }

    static var isAppleSilicon: Bool {
        machine == "arm64" || machine == "arm64e"
    }

    static func make() -> ChargeLimitBackend {
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 12 else {
            return UnsupportedBackend(
                reason: "Unsupported macOS version. batt-sail targets macOS Monterey 12 or newer."
            )
        }
        if isAppleSilicon {
            return AppleSiliconCHWABackend()
        }
        if machine == "x86_64" {
            return IntelBCLMBackend()
        }
        return UnsupportedBackend(reason: "Unsupported hardware architecture: \(machine).")
    }
}

// MARK: - Battery state via pmset

enum HardwareBridge {
    static func readBatteryInfo() throws -> BatteryInfo {
        let out = try Shell.run("/usr/bin/pmset", ["-g", "batt"])
        guard let line = out.split(separator: "\n").first(where: { $0.contains("%") }) else {
            throw BattSailError.shell("Unable to parse battery state from pmset output.")
        }

        let text = String(line)
        let regex = try NSRegularExpression(pattern: "(\\d+)%")
        guard let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text),
              let percent = Int(text[range]) else {
            throw BattSailError.shell("Battery percentage parse error.")
        }

        let fields = text.split(separator: ";").map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let rawState = fields.dropFirst().first ?? "unknown"
        let normalized = normalize(state: rawState, output: out)
        return BatteryInfo(percentage: percent, state: normalized)
    }

    private static func normalize(state: String, output: String) -> String {
        let lower = state.lowercased()
        if lower.contains("charged") { return "charged" }
        if lower.contains("not charging") { return "not charging" }
        if lower.contains("charging") { return "charging" }
        if lower.contains("discharging") { return "discharging" }
        if output.localizedCaseInsensitiveContains("AC Power") { return "AC Power" }
        if output.localizedCaseInsensitiveContains("Battery Power") { return "Battery Power" }
        return state
    }
}

// MARK: - Hysteresis

enum SailDecision: String {
    case lowerLimit = "lower-limit"
    case resumeCharging = "resume-charging"
    case hold = "hold"
}

struct EnforcementPlan {
    let battery: BatteryInfo
    let currentLimit: Int?
    let targetLimit: Int?
    let decision: SailDecision
    let reason: String
    let didWrite: Bool
}

enum HysteresisEngine {
    /// Compute the SMC target for the current battery reading.
    /// At max: target = minPercent - compensation (Intel BCLM only); clamped to >= 40.
    /// At min: target = 100.
    /// In between: nil (no action).
    static func target(
        forBattery batteryPercent: Int,
        config: AppConfig,
        backend: ChargeLimitBackend
    ) throws -> (Int?, SailDecision, String) {
        try Validator.validateBand(
            min: config.minPercent,
            max: config.maxPercent,
            compensation: config.intelDisplayCompensation
        )

        if batteryPercent >= config.maxPercent {
            let compensation = backend.kind == .intelBCLM ? config.intelDisplayCompensation : 0
            let raw = config.minPercent - compensation
            let target = Swift.max(40, raw)
            let reason = compensation > 0
                ? "battery >= max (\(config.maxPercent)%); lower limit to \(target)% (min \(config.minPercent) - comp \(compensation))"
                : "battery >= max (\(config.maxPercent)%); lower limit to \(target)%"
            return (target, .lowerLimit, reason)
        }
        if batteryPercent <= config.minPercent {
            return (100, .resumeCharging, "battery <= min (\(config.minPercent)%); restore limit to 100% to resume charging")
        }
        return (nil, .hold, "battery is inside sailing band \(config.minPercent)..\(config.maxPercent); no action")
    }

    static func plan(config: AppConfig, backend: ChargeLimitBackend) throws -> EnforcementPlan {
        let battery = try HardwareBridge.readBatteryInfo()
        let current = try? backend.readChargeLimit()
        let (target, decision, reason) = try target(
            forBattery: battery.percentage,
            config: config,
            backend: backend
        )
        return EnforcementPlan(
            battery: battery,
            currentLimit: current,
            targetLimit: target,
            decision: decision,
            reason: reason,
            didWrite: false
        )
    }

    static func enforce(
        config: AppConfig,
        backend: ChargeLimitBackend,
        dryRun: Bool
    ) throws -> EnforcementPlan {
        let base = try plan(config: config, backend: backend)
        guard let target = base.targetLimit else { return base }
        if dryRun { return base }
        if base.currentLimit == target { return base }

        try Validator.validateWriteLimit(target, backend: backend)
        let wrote = try backend.writeIfNeeded(target)
        return EnforcementPlan(
            battery: base.battery,
            currentLimit: base.currentLimit,
            targetLimit: target,
            decision: base.decision,
            reason: base.reason,
            didWrite: wrote
        )
    }
}

// MARK: - Daemon

enum Daemon {
    static let label = "com.mlkfs.batt-sail"
    static let plistPath = "/Library/LaunchDaemons/\(label).plist"
    static let defaultStartInterval = 21_600 // 6 hours
    static let stdoutPath = "/var/log/batt-sail.out"
    static let stderrPath = "/var/log/batt-sail.err"

    /// Plist labels that may collide with prior installations or sibling tools.
    static let legacyLabels = [
        "com.battsail.daemon",
        "com.mlkfs.bclm-sail"
    ]

    static func install(
        binaryPath: String = "/usr/local/bin/batt-sail",
        startInterval: Int = Daemon.defaultStartInterval
    ) throws {
        try Validator.requireRoot()

        // Bootout any older versions of this label, and any known legacy labels.
        bootoutLegacyDaemons()
        if isLoaded(label: Daemon.label) {
            _ = try? Shell.run("/bin/launchctl", ["bootout", "system", Daemon.plistPath])
        }

        let plist: [String: Any] = [
            "Label": Daemon.label,
            "ProgramArguments": [binaryPath, "enforce"],
            "RunAtLoad": true,
            "StartInterval": startInterval,
            "StandardOutPath": Daemon.stdoutPath,
            "StandardErrorPath": Daemon.stderrPath
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: URL(fileURLWithPath: Daemon.plistPath), options: .atomic)
        _ = try Shell.run("/bin/chmod", ["644", Daemon.plistPath])
        _ = try Shell.run("/usr/sbin/chown", ["root:wheel", Daemon.plistPath])

        do {
            _ = try Shell.run("/bin/launchctl", ["bootstrap", "system", Daemon.plistPath])
        } catch {
            throw BattSailError.shell("Failed to bootstrap LaunchDaemon: \(error)")
        }
    }

    @discardableResult
    static func uninstall() throws -> (bootedOut: Bool, removedPlist: Bool, removedLegacy: [String]) {
        try Validator.requireRoot()
        var bootedOut = false
        if isLoaded(label: Daemon.label) {
            _ = try? Shell.run("/bin/launchctl", ["bootout", "system", Daemon.plistPath])
            bootedOut = true
        }
        var removed = false
        if FileManager.default.fileExists(atPath: Daemon.plistPath) {
            try FileManager.default.removeItem(atPath: Daemon.plistPath)
            removed = true
        }
        let legacy = bootoutLegacyDaemons()
        return (bootedOut, removed, legacy)
    }

    static func start() throws {
        try Validator.requireRoot()
        _ = try Shell.run("/bin/launchctl", ["kickstart", "-k", "system/\(Daemon.label)"])
    }

    static func stop() throws {
        try Validator.requireRoot()
        if isLoaded(label: Daemon.label) {
            _ = try Shell.run("/bin/launchctl", ["bootout", "system", Daemon.plistPath])
        }
    }

    static func isLoaded(label: String = Daemon.label) -> Bool {
        let result = try? Shell.capture("/bin/launchctl", ["print", "system/\(label)"])
        return result?.exitCode == 0
    }

    @discardableResult
    static func bootoutLegacyDaemons() -> [String] {
        var booted: [String] = []
        for legacy in legacyLabels {
            let legacyPlist = "/Library/LaunchDaemons/\(legacy).plist"
            if isLoaded(label: legacy) {
                _ = try? Shell.run("/bin/launchctl", ["bootout", "system", legacyPlist])
                booted.append(legacy)
            }
        }
        return booted
    }

    /// Returns nil on success, an error string if the plist on disk is not a valid XML plist
    /// or does not match the expected schema.
    static func validatePlist() -> String? {
        guard FileManager.default.fileExists(atPath: Daemon.plistPath) else {
            return "plist not installed"
        }
        guard let data = FileManager.default.contents(atPath: Daemon.plistPath) else {
            return "plist unreadable"
        }
        var format = PropertyListSerialization.PropertyListFormat.xml
        let parsed: Any
        do {
            parsed = try PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: &format
            )
        } catch {
            return "plist parse error: \(error.localizedDescription)"
        }
        guard format == .xml else { return "plist must be XML format" }
        guard let dict = parsed as? [String: Any] else { return "plist root is not a dictionary" }
        guard (dict["Label"] as? String) == Daemon.label else {
            return "plist Label does not match \(Daemon.label)"
        }
        guard let args = dict["ProgramArguments"] as? [String], !args.isEmpty else {
            return "plist ProgramArguments missing"
        }
        guard args.last == "enforce" else {
            return "plist ProgramArguments must end with 'enforce'"
        }
        if dict["StartInterval"] == nil {
            return "plist StartInterval missing"
        }
        return nil
    }
}

// MARK: - Printing

func printPlan(_ plan: EnforcementPlan, backend: ChargeLimitBackend, dryRun: Bool) {
    print("Battery: \(plan.battery.percentage)% (\(plan.battery.state))")
    print("Backend: \(backend.kind.rawValue) (\(backend.status))")
    print("Current Limit: \(plan.currentLimit.map { "\($0)%" } ?? "unavailable")")
    print("Target Limit: \(plan.targetLimit.map { "\($0)%" } ?? "none")")
    print("Decision: \(plan.decision.rawValue) - \(plan.reason)")
    if dryRun {
        print("Write: dry-run; no SMC write performed")
    } else if plan.targetLimit == nil {
        print("Write: skipped (no action)")
    } else if plan.currentLimit == plan.targetLimit {
        print("Write: skipped (current limit already equals target)")
    } else if plan.didWrite {
        print("Write: applied")
    } else {
        print("Write: not applied")
    }
}

// MARK: - CLI

struct BattSail: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "batt-sail",
        abstract: "Battery sailing and charge limit manager for macOS",
        subcommands: [
            Status.self,
            Enforce.self,
            Custom.self,
            PresetCmd.self,
            ResetCmd.self,
            Doctor.self,
            BackendCmd.self,
            DaemonCmd.self
        ],
        defaultSubcommand: Status.self
    )
}

struct Status: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "Show battery, config, daemon, and backend status"
    )

    mutating func run() throws {
        let config = ConfigStore.loadOrDefault()
        let backend = BackendFactory.make()
        let battery = try? HardwareBridge.readBatteryInfo()
        let limit = try? backend.readChargeLimit()

        print("Battery: \(battery.map { "\($0.percentage)% (\($0.state))" } ?? "unavailable")")
        print("Backend: \(backend.kind.rawValue)")
        print("Backend Status: \(backend.status)")
        print("Native BCLM Available: \(backend.kind == .intelBCLM ? "yes" : "no")")
        print("Current Limit: \(limit.map { "\($0)%" } ?? "unavailable")")
        print("Config: \(ConfigStore.exists ? AppConfig.sharedPath : "missing; using defaults")")
        print("Mode: \(config.mode.rawValue) (min=\(config.minPercent), max=\(config.maxPercent), intelDisplayCompensation=\(config.intelDisplayCompensation))")
        print("Daemon: \(Daemon.isLoaded() ? "loaded" : "not loaded") (\(Daemon.label))")

        if let battery = battery {
            let recommendation: String
            if battery.percentage >= config.maxPercent {
                let target = Swift.max(40, config.minPercent - (backend.kind == .intelBCLM ? config.intelDisplayCompensation : 0))
                recommendation = "would lower limit to \(target)%"
            } else if battery.percentage <= config.minPercent {
                recommendation = "would set limit to 100% to resume charging"
            } else {
                recommendation = "hold; battery is inside band"
            }
            print("Next Action: \(recommendation)")
        }
    }
}

struct Enforce: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Apply sailing hysteresis once")

    @Flag(name: .customLong("dry-run"), help: "Print the decision without writing to SMC")
    var dryRun = false

    mutating func run() throws {
        let config = ConfigStore.loadOrDefault()
        let backend = BackendFactory.make()
        let plan = try HysteresisEngine.enforce(config: config, backend: backend, dryRun: dryRun)
        printPlan(plan, backend: backend, dryRun: dryRun)
    }
}

struct Custom: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Set a custom sailing band")

    @Option(name: .long, help: "Resume charging at or below this percent")
    var min: Int

    @Option(name: .long, help: "Stop charging at or above this percent")
    var max: Int

    @Option(name: .customLong("compensation"), help: "Intel display compensation in percentage points (default 3)")
    var compensation: Int?

    @Flag(name: .customLong("no-compensation"), help: "Disable Intel display compensation (sets it to 0)")
    var noCompensation = false

    mutating func run() throws {
        let resolvedCompensation: Int
        if noCompensation {
            resolvedCompensation = 0
        } else if let compensation = compensation {
            resolvedCompensation = compensation
        } else {
            resolvedCompensation = AppConfig.defaultConfig.intelDisplayCompensation
        }
        try Validator.validateBand(min: min, max: max, compensation: resolvedCompensation)
        let config = AppConfig(
            mode: .custom,
            minPercent: min,
            maxPercent: max,
            intelDisplayCompensation: resolvedCompensation
        )
        try ConfigStore.save(config)
        print("Saved custom sailing band min=\(min), max=\(max), intelDisplayCompensation=\(resolvedCompensation)")
    }
}

struct PresetCmd: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "preset",
        abstract: "Apply a preset sailing profile"
    )

    @Argument(help: "desktop")
    var type: String

    @Option(name: .customLong("compensation"), help: "Intel display compensation in percentage points (default 3)")
    var compensation: Int?

    @Flag(name: .customLong("no-compensation"), help: "Disable Intel display compensation")
    var noCompensation = false

    mutating func run() throws {
        guard type == "desktop" else {
            throw BattSailError.validation("Unknown preset: \(type). Available presets: desktop.")
        }
        let resolvedCompensation: Int
        if noCompensation {
            resolvedCompensation = 0
        } else if let compensation = compensation {
            resolvedCompensation = compensation
        } else {
            resolvedCompensation = AppConfig.defaultConfig.intelDisplayCompensation
        }
        let config = AppConfig(
            mode: .desktop,
            minPercent: 70,
            maxPercent: 80,
            intelDisplayCompensation: resolvedCompensation
        )
        try ConfigStore.save(config)
        print("Saved desktop preset min=70, max=80, intelDisplayCompensation=\(resolvedCompensation)")
    }
}

struct ResetCmd: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "reset",
        abstract: "Restore charging limit to 100"
    )

    @Flag(name: .customLong("remove-config"), help: "Also delete the saved sailing config")
    var removeConfig = false

    mutating func run() throws {
        let backend = BackendFactory.make()
        let wrote = try backend.writeIfNeeded(100)
        print(wrote ? "Charge limit reset to 100%." : "Charge limit was already 100%; no SMC write performed.")
        if removeConfig {
            let removed = try ConfigStore.remove()
            print(removed ? "Removed config at \(AppConfig.sharedPath)." : "No config to remove.")
        }
    }
}

struct Doctor: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Run environment checks")

    mutating func run() throws {
        let backend = BackendFactory.make()
        let machine = BackendFactory.machine
        let arch = BackendFactory.isAppleSilicon ? "Apple Silicon (\(machine))" : "Intel (\(machine))"

        print("macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        print("Architecture: \(arch)")
        print("Backend: \(backend.kind.rawValue)")
        print("Backend Status: \(backend.status)")

        if let battery = try? HardwareBridge.readBatteryInfo() {
            print("Battery: \(battery.percentage)% (\(battery.state))")
        } else {
            print("Battery: unavailable")
        }

        do {
            let limit = try backend.readChargeLimit()
            print("SMC Read: ok (\(limit)%)")
        } catch {
            print("SMC Read: failed - \(error)")
        }

        print("Write Privileges: \(getuid() == 0 ? "root (can write SMC)" : "not root; write commands require sudo")")
        print("Config: \(ConfigStore.exists ? "present at \(AppConfig.sharedPath)" : "missing (defaults will be used)")")

        if let plistError = Daemon.validatePlist() {
            print("LaunchDaemon plist: \(plistError)")
        } else {
            print("LaunchDaemon plist: valid XML at \(Daemon.plistPath)")
        }
        print("LaunchDaemon loaded: \(Daemon.isLoaded() ? "yes" : "no") (\(Daemon.label))")

        let logDir = "/var/log"
        let logWritable = FileManager.default.isWritableFile(atPath: logDir) || getuid() == 0
        print("Log dir \(logDir) writable: \(logWritable ? "yes" : "no")")

        let conflicting = Daemon.legacyLabels.filter { Daemon.isLoaded(label: $0) }
        if conflicting.isEmpty {
            print("Conflicting daemons: none")
        } else {
            print("Conflicting daemons loaded: \(conflicting.joined(separator: ", "))")
            print("  Run `sudo batt-sail daemon install` to bootout legacy daemons.")
        }
    }
}

struct BackendCmd: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "backend",
        abstract: "Show selected charge-limit backend"
    )

    mutating func run() throws {
        let backend = BackendFactory.make()
        print("Backend: \(backend.kind.rawValue)")
        print("Machine: \(BackendFactory.machine)")
        print("Key: \(backend.keyName ?? "none")")
        print("Status: \(backend.status)")
    }
}

struct DaemonCmd: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "daemon",
        abstract: "Manage the LaunchDaemon",
        subcommands: [
            DaemonInstall.self,
            DaemonUninstall.self,
            DaemonStart.self,
            DaemonStop.self
        ]
    )
}

struct DaemonInstall: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install and bootstrap the LaunchDaemon (runs every 6 hours)"
    )

    @Option(name: .customLong("interval"), help: "Override StartInterval in seconds (default 21600 = 6h)")
    var interval: Int?

    mutating func run() throws {
        let resolvedInterval = interval ?? Daemon.defaultStartInterval
        try Daemon.install(startInterval: resolvedInterval)
        print("Daemon installed at \(Daemon.plistPath)")
        print("Label: \(Daemon.label)")
        print("StartInterval: \(resolvedInterval) seconds")
        print("Logs: \(Daemon.stdoutPath), \(Daemon.stderrPath)")
        print("Bootstrapped into system domain.")
    }
}

struct DaemonUninstall: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Bootout and remove the LaunchDaemon plist (does not reset battery limit)"
    )

    mutating func run() throws {
        let result = try Daemon.uninstall()
        print("Bootout: \(result.bootedOut ? "performed" : "not needed")")
        print("Removed plist: \(result.removedPlist ? Daemon.plistPath : "not present")")
        if result.removedLegacy.isEmpty {
            print("Legacy daemons booted out: none")
        } else {
            print("Legacy daemons booted out: \(result.removedLegacy.joined(separator: ", "))")
        }
        print("Note: charge limit was not changed. Run `sudo batt-sail reset` to restore 100%.")
    }
}

struct DaemonStart: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "start",
        abstract: "Kickstart the LaunchDaemon"
    )

    mutating func run() throws {
        try Daemon.start()
        print("Daemon kickstarted.")
    }
}

struct DaemonStop: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "stop",
        abstract: "Bootout the LaunchDaemon"
    )

    mutating func run() throws {
        try Daemon.stop()
        print("Daemon stopped.")
    }
}

BattSail.main()
