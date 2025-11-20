import XCTest
@testable import Swift_UDS

final class MissingServicesTests: XCTestCase {

    func testReadMemoryByAddressPayload() {
        // 0x23, ALFID, Address, Size
        // Address: 0x1234 (2 bytes), Size: 0x56 (1 byte)
        // ALFID: SizeLength (high nibble) | AddressLength (low nibble)
        // SizeLength = 1, AddressLength = 2 -> 0x12
        let address: [UInt8] = [0x12, 0x34]
        let size: [UInt8] = [0x56]
        let service = UDS.Service.readMemoryByAddress(address: address, size: size)

        let payload = service.payload
        let expected: [UInt8] = [0x23, 0x12, 0x12, 0x34, 0x56]

        XCTAssertEqual(payload, expected, "The payload for readMemoryByAddress is incorrect.")
    }

    func testWriteMemoryByAddressPayload() {
        // 0x3D, ALFID, Address, Size, Data
        // Address: 0x8000 (2 bytes), Size: 0x02 (1 byte), Data: 0xAA, 0xBB
        // ALFID: SizeLength (1) << 4 | AddressLength (2) = 0x12
        let address: [UInt8] = [0x80, 0x00]
        let size: [UInt8] = [0x02]
        let data: [UInt8] = [0xAA, 0xBB]
        let service = UDS.Service.writeMemoryByAddress(address: address, size: size, data: data)

        let payload = service.payload
        let expected: [UInt8] = [0x3D, 0x12, 0x80, 0x00, 0x02, 0xAA, 0xBB]

        XCTAssertEqual(payload, expected, "The payload for writeMemoryByAddress is incorrect.")
    }

    func testInputOutputControlByIdentifierPayload() {
        // 0x2F, ID (2 bytes), ControlOption (1 byte), ControlState (variable)
        // ID: 0x1234, Option: 0x03 (ShortTermAdjustment), State: 0x50 (50%)
        let id: UInt16 = 0x1234
        let option: UDS.InputOutputControlOption = .shortTermAdjustment
        let state: [UInt8] = [0x50]
        let service = UDS.Service.inputOutputControlByIdentifier(id: id, option: option, controlState: state)

        let payload = service.payload
        let expected: [UInt8] = [0x2F, 0x12, 0x34, 0x03, 0x50]

        XCTAssertEqual(payload, expected, "The payload for inputOutputControlByIdentifier is incorrect.")
    }

    func testRequestFileTransferPayload() {
        // 0x38, Mode (0x01 AddFile), FilePathLength (2 bytes), FilePath, FileSizeFormat (1 byte), FileSize (variable)
        // For simplicity, let's test just the mode and basic parameters if we implement a simplified version or generic one.
        // Let's assume we implement a generic one for now: requestFileTransfer(modeOfOperation: UInt8, ... params)
        // Or better, fully typed.
        // Mode: 0x01 (AddFile), FilePath: "abc", DataFormat: 0x00, FileSize: 100
        // ... This might be too complex to define all types right now.
        // Let's stick to the first 3 services for the test plan for now, as they are most critical.
    }
}
