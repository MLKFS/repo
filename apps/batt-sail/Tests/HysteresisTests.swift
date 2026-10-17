func assertEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #file, line: UInt = #line) {
    precondition(actual == expected, "Expected \(expected), got \(actual)", file: file, line: line)
}
func assertNil<T>(_ value: T?, file: StaticString = #file, line: UInt = #line) {
    precondition(value == nil, "Expected nil", file: file, line: line)
}
func assertThrowsError<T>(_ expression: @autoclosure () throws -> T) {
    do { _ = try expression() } catch { return }
    preconditionFailure("Expected an error")
}

final class HysteresisTests {
    let config = AppConfig(mode: .custom, minPercent: 60, maxPercent: 80, intelDisplayCompensation: 3)
    let backend = IntelBCLMBackend()

    func testIntelResumesWithUpperCeilingInsteadOf100() throws {
        for percentage in [10, 59, 60] {
            let (target, decision, _) = try HysteresisEngine.target(forBattery: percentage, config: config, backend: backend)
            assertEqual(target, 77)
            assertEqual(decision, .resumeCharging)
        }
    }

    func testIntelStopsAtUpperThreshold() throws {
        for percentage in [80, 81, 100] {
            let (target, decision, _) = try HysteresisEngine.target(forBattery: percentage, config: config, backend: backend)
            assertEqual(target, 57)
            assertEqual(decision, .lowerLimit)
        }
    }

    func testInsideBandPreservesChargeState() throws {
        for percentage in 61...79 {
            let (target, decision, _) = try HysteresisEngine.target(forBattery: percentage, config: config, backend: backend)
            assertNil(target)
            assertEqual(decision, .hold)
        }
    }

    func testAppleSiliconRetainsSupportedValues() throws {
        let silicon = AppleSiliconCHWABackend()
        assertEqual(try HysteresisEngine.target(forBattery: 60, config: config, backend: silicon).0, 100)
        assertEqual(try HysteresisEngine.target(forBattery: 80, config: config, backend: silicon).0, 80)
    }

    func testLegacyConfigStillDecodes() throws {
        let data = Data(#"{"mode":"desktop","minLimit":50,"maxLimit":55}"#.utf8)
        let legacy = try JSONDecoder().decode(AppConfig.self, from: data)
        assertEqual(legacy.minPercent, 50)
        assertEqual(legacy.maxPercent, 55)
        assertEqual(legacy.intelDisplayCompensation, 3)
    }

    func testInvalidBandIsRejectedBeforePlanning() {
        let invalid = AppConfig(mode: .custom, minPercent: 80, maxPercent: 70, intelDisplayCompensation: 3)
        assertThrowsError(try HysteresisEngine.target(forBattery: 10, config: invalid, backend: backend))
    }

    func testMinutePollingDefault() {
        assertEqual(Daemon.defaultStartInterval, 60)
    }
}

let tests = HysteresisTests()
try tests.testIntelResumesWithUpperCeilingInsteadOf100()
try tests.testIntelStopsAtUpperThreshold()
try tests.testInsideBandPreservesChargeState()
try tests.testAppleSiliconRetainsSupportedValues()
try tests.testLegacyConfigStillDecodes()
tests.testInvalidBandIsRejectedBeforePlanning()
tests.testMinutePollingDefault()
let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temporary) }
let configPath = temporary.appendingPathComponent("config.json")
assertEqual(try ConfigStore.loadOrDefault(path: configPath.path).maxPercent, 80)
try Data("broken json".utf8).write(to: configPath)
assertThrowsError(try ConfigStore.loadOrDefault(path: configPath.path))
try Data(#"{"minPercent":90,"maxPercent":70}"#.utf8).write(to: configPath)
assertThrowsError(try ConfigStore.loadOrDefault(path: configPath.path))
try Data(#"{"minLimit":60,"maxLimit":80}"#.utf8).write(to: configPath)
assertEqual(try ConfigStore.loadOrDefault(path: configPath.path).minPercent, 60)
for interval in [0, -1, Int(Int32.max) + 1] {
    assertThrowsError(try Daemon.validateInstall(binaryPath: "/bin/echo", startInterval: interval))
}
for path in ["relative/path", "/no/such/batt-sail", temporary.path] {
    assertThrowsError(try Daemon.validateInstall(binaryPath: path, startInterval: 60))
}
try Daemon.validateInstall(binaryPath: "/bin/echo", startInterval: 60)
struct FakeBackend: ChargeLimitBackend {
    let kind = BackendKind.intelBCLM
    let keyName: String? = "BCLM"
    let status = "test"
    let value: Int
    func readChargeLimit() throws -> Int { value }
    func writeChargeLimit(_ percent: Int) throws { preconditionFailure("Tests must never write") }
}
try FakeBackend(value: 77).verifyChargeLimit(77)
assertThrowsError(try FakeBackend(value: 100).verifyChargeLimit(77))
print("PASS: hysteresis, config errors, daemon validation, write verification (no SMC writes)")
