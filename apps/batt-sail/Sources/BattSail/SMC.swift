//
// Native SMC access for batt-sail.
//
// Based on concepts/code from zackelia/bclm:
// https://github.com/zackelia/bclm
//
// bclm is MIT licensed.
// Copyright (c) 2020 Zack Elia
//
// The SMC client below is adapted from SMCKit, also MIT licensed.
// Copyright (C) 2014-2017 beltex <https://beltex.github.io>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import IOKit

typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

extension UInt32 {
    init(fourCharCode string: String) {
        precondition(string.utf8.count == 4)
        self = string.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    var fourCharString: String {
        let bytes: [UInt8] = [
            UInt8((self >> 24) & 0xff),
            UInt8((self >> 16) & 0xff),
            UInt8((self >> 8) & 0xff),
            UInt8(self & 0xff)
        ]
        return String(bytes: bytes, encoding: .ascii) ?? String(format: "0x%08X", self)
    }
}

struct SMCDataType: Equatable {
    let type: UInt32
    let size: UInt32
}

enum SMCDataTypes {
    static let ui8 = SMCDataType(type: UInt32(fourCharCode: "ui8 "), size: 1)
}

struct SMCKey {
    let code: UInt32
    let info: SMCDataType
}

struct SMCParamStruct {
    enum Selector: UInt8 {
        case handleYPCEvent = 2
        case readKey = 5
        case writeKey = 6
    }

    enum Result: UInt8 {
        case success = 0
        case keyNotFound = 132
    }

    struct Version {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }

    struct PLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }

    struct KeyInfoData {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var vers = Version()
    var pLimitData = PLimitData()
    var keyInfo = KeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = SMC.makeBytes(0)
}

enum SMCError: Error, CustomStringConvertible {
    case driverNotFound
    case failedToOpen(kern_return_t)
    case keyNotFound(String)
    case notPrivileged
    case unsupported(String)
    case unknown(kIOReturn: kern_return_t, smcResult: UInt8)

    var description: String {
        switch self {
        case .driverNotFound:
            return "AppleSMC driver was not found on this Mac."
        case .failedToOpen(let code):
            return "Failed to open AppleSMC connection (IOKit return \(code))."
        case .keyNotFound(let key):
            return "SMC key \(key) was not found on this Mac."
        case .notPrivileged:
            return "SMC write was rejected because root privileges are required."
        case .unsupported(let message):
            return message
        case .unknown(let ioReturn, let smcResult):
            return "SMC call failed (IOKit return \(ioReturn), SMC result \(smcResult))."
        }
    }
}

final class SMC {
    private var connection: io_connect_t = 0

    static func makeBytes(_ first: UInt8) -> SMCBytes {
        (
            first, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0
        )
    }

    func open() throws {
        // kIOMainPortDefault renames kIOMasterPortDefault on macOS 12+.
        // Both resolve to 0; passing 0 is portable across SDKs shipped
        // with older Monterey Command Line Tools.
        let mainPort: mach_port_t = 0
        let service = IOServiceGetMatchingService(mainPort, IOServiceMatching("AppleSMC"))
        guard service != 0 else { throw SMCError.driverNotFound }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard result == kIOReturnSuccess else { throw SMCError.failedToOpen(result) }
    }

    deinit {
        close()
    }

    func close() {
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    func readUInt8(key: String) throws -> UInt8 {
        let data = try readData(SMCKey(code: UInt32(fourCharCode: key), info: SMCDataTypes.ui8))
        return data.0
    }

    func writeUInt8(key: String, value: UInt8) throws {
        try writeData(SMCKey(code: UInt32(fourCharCode: key), info: SMCDataTypes.ui8), data: SMC.makeBytes(value))
    }

    private func readData(_ key: SMCKey) throws -> SMCBytes {
        var input = SMCParamStruct()
        input.key = key.code
        input.keyInfo.dataSize = UInt32(key.info.size)
        input.data8 = SMCParamStruct.Selector.readKey.rawValue
        return try callDriver(&input).bytes
    }

    private func writeData(_ key: SMCKey, data: SMCBytes) throws {
        var input = SMCParamStruct()
        input.key = key.code
        input.bytes = data
        input.keyInfo.dataSize = UInt32(key.info.size)
        input.data8 = SMCParamStruct.Selector.writeKey.rawValue
        _ = try callDriver(&input)
    }

    private func callDriver(_ input: inout SMCParamStruct) throws -> SMCParamStruct {
        assert(MemoryLayout<SMCParamStruct>.stride == 80, "SMCParamStruct size is not 80 bytes")

        var output = SMCParamStruct()
        var outputSize = MemoryLayout<SMCParamStruct>.stride
        let inputSize = MemoryLayout<SMCParamStruct>.stride
        let result = IOConnectCallStructMethod(
            connection,
            UInt32(SMCParamStruct.Selector.handleYPCEvent.rawValue),
            &input,
            inputSize,
            &output,
            &outputSize
        )

        switch (result, output.result) {
        case (kIOReturnSuccess, SMCParamStruct.Result.success.rawValue):
            return output
        case (kIOReturnSuccess, SMCParamStruct.Result.keyNotFound.rawValue):
            throw SMCError.keyNotFound(input.key.fourCharString)
        case (kIOReturnNotPrivileged, _):
            throw SMCError.notPrivileged
        default:
            throw SMCError.unknown(kIOReturn: result, smcResult: output.result)
        }
    }
}
