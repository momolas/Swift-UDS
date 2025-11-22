//
//  KWPTests.swift
//  SwiftUDSTests
//

import XCTest
@testable import Swift_UDS

final class KWPTests: XCTestCase {

    func testSingleFrameEncoding() throws {
        let encoder = UDS.KWP.Encoder()
        let payload: [UInt8] = [0x01, 0x02, 0x03]
        let encoded = try encoder.encode(payload)
        // Expect [0x03, 0x01, 0x02, 0x03] (PCI=03, Data)
        XCTAssertEqual(encoded, [0x03, 0x01, 0x02, 0x03])
    }

    func testMultiFrameEncoding() throws {
        let encoder = UDS.KWP.Encoder()
        // Create a payload of 10 bytes (more than 7, triggers FF/CF)
        let payload = Array<UInt8>(repeating: 0xAA, count: 10)
        let encoded = try encoder.encode(payload)

        // First Frame (FF):
        // PCI = 0x100A (1AAA AAAA AAAA) -> 10 0A
        // Data: AA AA AA AA AA AA (6 bytes)
        // Total FF: 10 0A AA AA AA AA AA AA (8 bytes)

        // Consecutive Frame (CF):
        // PCI = 0x21 (Sequence Number starts at 1)
        // Data: AA AA AA AA (4 bytes remaining)
        // Total CF: 21 AA AA AA AA (5 bytes)

        let expectedFF: [UInt8] = [0x10, 0x0A, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA]
        let expectedCF: [UInt8] = [0x21, 0xAA, 0xAA, 0xAA, 0xAA]

        // The encoder returns all frames concatenated
        XCTAssertEqual(encoded.count, 8 + 5)
        XCTAssertEqual(Array(encoded[0..<8]), expectedFF)
        XCTAssertEqual(Array(encoded[8...]), expectedCF)
    }

    func testExactlySevenBytesEncoding() throws {
        let encoder = UDS.KWP.Encoder()
        let payload = Array<UInt8>(repeating: 0xBB, count: 7)
        let encoded = try encoder.encode(payload)

        // Expect Single Frame: PCI=07, Data=BB...
        // [0x07, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB, 0xBB]
        var expected: [UInt8] = [0x07]
        expected.append(contentsOf: payload)

        XCTAssertEqual(encoded, expected)
    }

    func testEmptyEncoding() {
        let encoder = UDS.KWP.Encoder()
        XCTAssertThrowsError(try encoder.encode([])) { error in
            if let udsError = error as? UDS.Error, case .encoderError = udsError {
                // Success
            } else {
                XCTFail("Expected UDS.Error.encoderError")
            }
        }
    }

    func testTooLargeEncoding() {
        let encoder = UDS.KWP.Encoder()
        let payload = Array<UInt8>(repeating: 0x00, count: 4096)
        XCTAssertThrowsError(try encoder.encode(payload)) { error in
            if let udsError = error as? UDS.Error, case .encoderError = udsError {
                // Success
            } else {
                XCTFail("Expected UDS.Error.encoderError")
            }
        }
    }
}
