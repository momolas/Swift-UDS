//
//  ISOTPTransmitterTests.swift
//  SwiftUDSTests
//

import XCTest
@testable import Swift_UDS

final class ISOTPTransmitterTests: XCTestCase {

    func testSingleFrame() throws {
        let payload: [UInt8] = [0x01, 0x02, 0x03]
        let transmitter = UDS.ISOTP.Transmitter(payload: payload)

        let firstFrame = try transmitter.start()
        XCTAssertEqual(firstFrame, [0x03, 0x01, 0x02, 0x03])
        XCTAssertEqual(transmitter.state, .completed)
    }

    func testMultiFrameNoBlockSize() throws {
        // 10 bytes payload
        let payload = Array<UInt8>(repeating: 0xAA, count: 10)
        let transmitter = UDS.ISOTP.Transmitter(payload: payload)

        // 1. Start -> FF
        let ff = try transmitter.start()
        // FF: 10 0A AA... (6 bytes)
        XCTAssertEqual(ff.count, 8)
        XCTAssertEqual(ff[0], 0x10)
        XCTAssertEqual(ff[1], 0x0A)
        XCTAssertEqual(transmitter.state, .waitingForFlowControl)

        // 2. Receive Flow Control (BlockSize = 0, STmin = 0)
        // 30 00 00
        let continueToSend = transmitter.receiveFlowControl(bytes: [0x30, 0x00, 0x00])
        XCTAssertTrue(continueToSend)
        XCTAssertEqual(transmitter.state, .sendingConsecutiveFrames)

        // 3. Next Frame -> CF
        // Remaining 4 bytes
        guard let output = transmitter.nextFrame(), case .frame(let cf) = output else {
            XCTFail("Expected CF")
            return
        }
        // CF: 21 AA AA AA AA
        XCTAssertEqual(cf, [0x21, 0xAA, 0xAA, 0xAA, 0xAA])

        // 4. Check completion
        if case .completed = transmitter.state {
            // OK
        } else {
            // Depending on implementation, nextFrame might need to be called again to transition to complete or it happened in previous call
             XCTAssertEqual(transmitter.state, .completed)
        }
    }

    func testMultiFrameWithBlockSize() throws {
        // 20 bytes payload -> FF(6) + CF(7) + CF(7)
        let payload = Array<UInt8>(repeating: 0xBB, count: 20)
        let transmitter = UDS.ISOTP.Transmitter(payload: payload)

        // 1. Start
        _ = try transmitter.start()
        XCTAssertEqual(transmitter.state, .waitingForFlowControl)

        // 2. Receive FC (BlockSize = 1)
        _ = transmitter.receiveFlowControl(bytes: [0x30, 0x01, 0x00])

        // 3. Get CF 1
        guard let out1 = transmitter.nextFrame(), case .frame(let cf1) = out1 else { XCTFail(); return }
        XCTAssertEqual(cf1[0], 0x21)

        // 4. Should be waiting for FC now because BlockSize was 1
        let out2 = transmitter.nextFrame()
        XCTAssertNil(out2)
        XCTAssertEqual(transmitter.state, .waitingForFlowControl)

        // 5. Receive 2nd FC (BlockSize = 0, finish it)
        _ = transmitter.receiveFlowControl(bytes: [0x30, 0x00, 0x00])
        XCTAssertEqual(transmitter.state, .sendingConsecutiveFrames)

        // 6. Get CF 2
        guard let out3 = transmitter.nextFrame(), case .frame(let cf2) = out3 else { XCTFail(); return }
        XCTAssertEqual(cf2[0], 0x22)

        XCTAssertEqual(transmitter.state, .completed)
    }

    func testOverflow() throws {
        let payload = Array<UInt8>(repeating: 0xCC, count: 10)
        let transmitter = UDS.ISOTP.Transmitter(payload: payload)
        _ = try transmitter.start()

        // Receive Overflow (32 ...)
        let result = transmitter.receiveFlowControl(bytes: [0x32, 0x00, 0x00])
        XCTAssertFalse(result)

        if case .error(let msg) = transmitter.state {
            XCTAssertEqual(msg, "Receiver overflow")
        } else {
            XCTFail("Expected overflow error")
        }
    }
}
