//
//  ProtocolTests.swift
//  SwiftUDSTests
//

import XCTest
@testable import Swift_UDS

final class ProtocolTests: XCTestCase {

    func testISOTPEncoding() throws {
        let encoder = UDS.ISOTP.Encoder()
        try verifyEncoding(with: encoder)
    }

    func testKWPEncoding() throws {
        let encoder = UDS.KWP.Encoder()
        try verifyEncoding(with: encoder)
    }

    func testISO9141Encoding() throws {
        let encoder = UDS.ISO9141.Encoder()
        try verifyEncoding(with: encoder)
    }

    func testJ1850Encoding() throws {
        let encoder = UDS.J1850.Encoder()
        try verifyEncoding(with: encoder)
    }

    private func verifyEncoding(with encoder: UDS.BusProtocolEncoder) throws {
        // 1. Single Frame (<7 bytes)
        let smallPayload: [UInt8] = [0x01, 0x02]
        let smallEncoded = try encoder.encode(smallPayload)
        XCTAssertEqual(smallEncoded, [0x02, 0x01, 0x02])

        // 2. Single Frame (7 bytes - boundary check)
        let boundaryPayload = Array<UInt8>(repeating: 0xBB, count: 7)
        let boundaryEncoded = try encoder.encode(boundaryPayload)
        XCTAssertEqual(boundaryEncoded, [0x07] + boundaryPayload)

        // 3. Multi Frame (> 7 bytes)
        // 10 bytes payload
        let largePayload = Array<UInt8>(repeating: 0xAA, count: 10)
        let largeEncoded = try encoder.encode(largePayload)

        // First Frame (FF): 10 0A + 6 bytes data
        let expectedFF: [UInt8] = [0x10, 0x0A] + Array(largePayload.prefix(6))
        // Consecutive Frame (CF): 21 + 4 bytes data
        let expectedCF: [UInt8] = [0x21] + Array(largePayload.suffix(4))

        XCTAssertEqual(largeEncoded.count, 8 + 5)
        XCTAssertEqual(Array(largeEncoded.prefix(8)), expectedFF)
        XCTAssertEqual(Array(largeEncoded.suffix(5)), expectedCF)
    }
}
