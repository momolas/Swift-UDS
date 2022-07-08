import XCTest
@testable import Swift_UDS

/// Create the necessary frames to transmit 4095 random bytes via ISOTP
private func createMaximumPayloadFrames() -> (payload: [UInt8], firstFrame: [UInt8], consecutiveFrames: [[UInt8]]) {
    var payload: [UInt8] = []
    for _ in 0..<UDS.ISOTP.MaximumFrameSize {
        payload.append(UInt8.random(in: 0x00...0xFF))
    }
    XCTAssertEqual(payload.count, 4095)
    let expectedPayload = payload
    
    var cfs: [[UInt8]] = []
    let ff: [UInt8] = [0x1F, 0xFF] + Array(payload.prefix(6))
    payload = Array(payload.dropFirst(6))
    var seqNum: UInt8 = 0x21
    while !payload.isEmpty {
        let cf: [UInt8] = [seqNum] + Array(payload.prefix(7))
        payload = Array(payload.dropFirst(7))
        cfs.append(cf)
        seqNum += 1
        if seqNum == 0x30 { seqNum = 0x20 }
    }
    return (expectedPayload, ff, cfs)
}

final class ISOTPTests: XCTestCase {

    ///
    /// READ Tests without protocol violations
    ///
    func testStartsOutWithIdle() throws {
        let isotp = UDS.ISOTP.Transceiver()
        XCTAssert(isotp.state == .idle)
    }
    
    func testReadValidSingleFrame() throws {

        let isotp = UDS.ISOTP.Transceiver()
        
        let frame: [UInt8] = [
            0x02,
            0x09, 0x02,
            0xAA, 0xAA, 0xAA, 0xAA, 0xAA
        ]
        let action = try isotp.didRead(bytes: frame)
        XCTAssert(isotp.state == .idle)
        XCTAssertEqual(action, .process(bytes: [0x09, 0x02]))
    }
    
    func testReadValidFFCF() throws {
        
        let isotp = UDS.ISOTP.Transceiver(blockSize: 0x40, separationTimeMs: 0x01)

        let ff: [UInt8] = [
            0x10, 0x08,
            0x11, 0x22, 0x33, 0x44, 0x55, 0x66
        ]
        var action = try isotp.didRead(bytes: ff)
        XCTAssert(isotp.state == .receiving)
        XCTAssertEqual(action, .writeFrames([[0x30, 0x40, 0x01]], separationTime: 0, isLastBatch: false))

        let cf: [UInt8] = [
            0x21, 0x77, 0x88,
            0xAA, 0xAA, 0xAA, 0xAA, 0xAA
        ]
        action = try isotp.didRead(bytes: cf)
        XCTAssert(isotp.state == .idle)
        XCTAssertEqual(action, .process(bytes: [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]))
    }

    func testReadMaximumLengthNoFlowControl() throws {

        var (expectedPayload, ff, cfs) = createMaximumPayloadFrames()
        
        let isotp = UDS.ISOTP.Transceiver(blockSize: 0x00, separationTimeMs: 0x01)
        let action = try isotp.didRead(bytes: ff)
        XCTAssert(isotp.state == .receiving)
        XCTAssertEqual(action, .writeFrames([[0x30, 0x00, 0x01]], separationTime: 0, isLastBatch: false))
        
        while isotp.state == .receiving {
            var cf = cfs.first!
            while cf.count < 8 { cf.append(0xAA) }
            cfs = Array(cfs.dropFirst())
            let action = try isotp.didRead(bytes: cf)
            switch action {
                case .waitForMore:
                    break
                case .process(let receivedPayload):
                    XCTAssertEqual(receivedPayload, expectedPayload)
                default:
                    XCTAssertEqual(0, 1)
            }
        }
    }

    func testReadMaximumLengthWithFlowControl() throws {
        
        var (expectedPayload, ff, cfs) = createMaximumPayloadFrames()

        let blockSize: UInt8 = 0x7F // maximum number of unACKed frames
        
        let isotp = UDS.ISOTP.Transceiver(blockSize: blockSize, separationTimeMs: 0x01)
        let action = try isotp.didRead(bytes: ff)
        XCTAssert(isotp.state == .receiving)
        XCTAssertEqual(action, .writeFrames([[0x30, blockSize, 0x01]], separationTime: 0, isLastBatch: false))
        
        var unACKtimer = blockSize - 1
        
        while isotp.state == .receiving {
            var cf = cfs.first!
            while cf.count < 8 { cf.append(0xAA) }
            cfs = Array(cfs.dropFirst())
            let action = try isotp.didRead(bytes: cf)
            switch action {
                case .waitForMore:
                    unACKtimer -= 1
                case .writeFrames(let frames, _, _):
                    XCTAssertEqual(frames.count, 1)
                    XCTAssertTrue(unACKtimer == 0x00)
                    unACKtimer = blockSize - 1
                case .process(let receivedPayload):
                    XCTAssertEqual(receivedPayload, expectedPayload)
                default:
                    XCTAssertEqual(0, 1)
            }
        }
    }
    
    ///
    /// WRITE Tests without protocol violations
    ///
    func testWriteValidSingleFrame() throws {
        
        let bytes: [UInt8] = [0x09, 0x02]
        let isotp = UDS.ISOTP.Transceiver()
        let action = try isotp.write(bytes: bytes)
        XCTAssert(isotp.state == .idle)

        let sf = [UInt8(bytes.count)] + bytes
        XCTAssertEqual(action, .writeFrames([sf], separationTime: 0, isLastBatch: true))
    }
    
    func testWriteValidFFCF() throws {
        
        let bytes: [UInt8] = [0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88]

        let ff: [UInt8] = [
            0x10, 0x08,
            0x11, 0x22, 0x33, 0x44, 0x55, 0x66
        ]
        let cf: [UInt8] = [
            0x21, 0x77, 0x88,
            /* 0xAA, 0xAA, 0xAA, 0xAA, 0xAA */
        ]

        let isotp = UDS.ISOTP.Transceiver()
        var action = try isotp.write(bytes: bytes)
        XCTAssert(isotp.state == .sending)
        XCTAssertEqual(action, .writeFrames([ff], separationTime: 0, isLastBatch: false))

        let fc: [UInt8] = [
            0x30, 0x00, 0x01,
            0xAA, 0xAA, 0xAA, 0xAA, 0xAA
        ]

        action = try isotp.didRead(bytes: fc)
        XCTAssert(isotp.state == .idle)
        XCTAssertEqual(action, .writeFrames([cf], separationTime: 1, isLastBatch: true))
    }
    
    func testWriteMaximumLengthWithFlowControl() throws {
        
        var payload: [UInt8] = []
        for _ in 0..<UDS.ISOTP.MaximumFrameSize {
            payload.append(UInt8.random(in: 0x00...0xFF))
        }
        XCTAssertEqual(payload.count, 4095)
        
        let isotp = UDS.ISOTP.Transceiver()
        let action = try isotp.write(bytes: payload)
        XCTAssertEqual(isotp.state, .sending)

        let ff: [UInt8] = [0x1F, 0xFF] + Array(payload.prefix(6))
        XCTAssertEqual(action, .writeFrames([ff], separationTime: 0, isLastBatch: false))
        payload = Array(payload.dropFirst(6))

        let separationTime: UInt8 = 0x03
        let blockSize: UInt8 = 0x1F
        var seqNo: UInt8 = 0x21

        while !payload.isEmpty {

            XCTAssertEqual(isotp.state, .sending)
            let action = try isotp.didRead(bytes: [0x30, blockSize, separationTime, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA])
            guard case let .writeFrames(frames, separationTimeMs, _) = action else { return XCTAssert(false) }
            XCTAssertLessThanOrEqual(UInt8(frames.count), blockSize)
            XCTAssertEqual(separationTimeMs, separationTime)
            for frame in frames {
                XCTAssertEqual(seqNo, frame[0])
                seqNo += 1
                if seqNo == 0x30 { seqNo = 0x20 }
                let payloadBytesInFrame = min(7, payload.count)
                XCTAssertEqual(frame[1...payloadBytesInFrame], payload.prefix(payloadBytesInFrame))
                payload = Array(payload.dropFirst(payloadBytesInFrame))
            }
        }
        XCTAssert(isotp.state == .idle)
    }
    
    func testWriteMaximumLengthNoFlowControl() throws {
        
        var payload: [UInt8] = []
        for _ in 0..<UDS.ISOTP.MaximumFrameSize {
            payload.append(UInt8.random(in: 0x00...0xFF))
        }
        XCTAssertEqual(payload.count, 4095)
        
        let isotp = UDS.ISOTP.Transceiver()
        var action = try isotp.write(bytes: payload)
        XCTAssertEqual(isotp.state, .sending)
        
        let ff: [UInt8] = [0x1F, 0xFF] + Array(payload.prefix(6))
        XCTAssertEqual(action, .writeFrames([ff], separationTime: 0, isLastBatch: false))
        payload = Array(payload.dropFirst(6))
        
        var seqNo: UInt8 = 0x21
        
        action = try isotp.didRead(bytes: [0x30, 0x00, 0x01, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA])
        guard case let .writeFrames(frames, _, _) = action else { return XCTAssert(false) }
        XCTAssertLessThanOrEqual(frames.count, UDS.ISOTP.MaximumFrames - 1)
        for frame in frames {
            XCTAssertEqual(seqNo, frame[0])
            seqNo += 1
            if seqNo == 0x30 { seqNo = 0x20 }
            let payloadBytesInFrame = min(7, payload.count)
            XCTAssertEqual(frame[1...payloadBytesInFrame], payload.prefix(payloadBytesInFrame))
            payload = Array(payload.dropFirst(payloadBytesInFrame))
        }
        XCTAssertTrue(payload.isEmpty)
        XCTAssert(isotp.state == .idle)
    }

    ///
    /// READ Tests _with_ protocol violations in `.strict` behavior
    ///
    func testReadEmptySF() throws {
        
        let frame: [UInt8] = []
        let isotp = UDS.ISOTP.Transceiver(behavior: .strict)
        XCTAssertThrowsError(try isotp.didRead(bytes: frame)) { error in
            guard case UDS.ISOTP.Transceiver.Error.protocolViolation(_) = error else { return XCTAssertFalse(true) }
        }
    }

    func testReadShortSF() throws {

        let frame: [UInt8] = [0x05, 0x01, 0x02, 0x03, 0x04]
        let isotp = UDS.ISOTP.Transceiver(behavior: .strict)
        XCTAssertThrowsError(try isotp.didRead(bytes: frame)) { error in
            guard case UDS.ISOTP.Transceiver.Error.protocolViolation(_) = error else { return XCTAssertFalse(true) }
        }
    }
    
    func testReadLongSF() throws {

        let frame: [UInt8] = [0x05, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0a]
        let isotp = UDS.ISOTP.Transceiver(behavior: .strict)
        XCTAssertThrowsError(try isotp.didRead(bytes: frame)) { error in
            guard case UDS.ISOTP.Transceiver.Error.protocolViolation(_) = error else { return XCTAssertFalse(true) }
        }
    }
    
    func testReadInvalidFrameType() throws {

        let frame: [UInt8] = [0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let isotp = UDS.ISOTP.Transceiver(behavior: .strict)
        XCTAssertThrowsError(try isotp.didRead(bytes: frame)) { error in
            guard case UDS.ISOTP.Transceiver.Error.protocolViolation(_) = error else { return XCTAssertFalse(true) }
        }
    }

    func testReadInvalidSFLength() throws {
        
        let frame: [UInt8] = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let isotp = UDS.ISOTP.Transceiver(behavior: .strict)
        XCTAssertThrowsError(try isotp.didRead(bytes: frame)) { error in
            guard case UDS.ISOTP.Transceiver.Error.protocolViolation(_) = error else { return XCTAssertFalse(true) }
        }
    }
    
    func testReadInvalidFFLength() throws {
        
        let frame: [UInt8] = [0x10, 0x05, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let isotp = UDS.ISOTP.Transceiver(behavior: .strict)
        XCTAssertThrowsError(try isotp.didRead(bytes: frame)) { error in
            guard case UDS.ISOTP.Transceiver.Error.protocolViolation(_) = error else { return XCTAssertFalse(true) }
        }
    }

    func testInvalidSegmentation() throws {
        
        let ff: [UInt8] = [0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let cf: [UInt8] = [0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let isotp = UDS.ISOTP.Transceiver(behavior: .strict)
        _ = try isotp.didRead(bytes: ff)
        XCTAssertThrowsError(try isotp.didRead(bytes: cf)) { error in
            guard case UDS.ISOTP.Transceiver.Error.protocolViolation(_) = error else { return XCTAssertFalse(true) }
        }
    }

    func testOverflow() throws {
        
        let ff:  [UInt8] = [0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let cf1: [UInt8] = [0x21, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let cf2: [UInt8] = [0x22, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let cf3: [UInt8] = [0x22, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let isotp = UDS.ISOTP.Transceiver(behavior: .strict)
        _ = try isotp.didRead(bytes: ff)
        _ = try isotp.didRead(bytes: cf1)
        _ = try isotp.didRead(bytes: cf2)
        XCTAssertThrowsError(try isotp.didRead(bytes: cf3)) { error in
            guard case UDS.ISOTP.Transceiver.Error.protocolViolation(_) = error else { return XCTAssertFalse(true) }
        }
    }
    
    ///
    /// READ Tests _with_ protocol violations in `.defensive` behavior
    ///
    func testMixedUpOrderConsecutiveFrames() throws {
        
        let ff:  [UInt8] = [0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let cf1: [UInt8] = [0x21, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let cf2: [UInt8] = [0x22, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let cf3: [UInt8] = [0x27, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let isotp = UDS.ISOTP.Transceiver(behavior: .defensive)
        _ = try isotp.didRead(bytes: ff)
        _ = try isotp.didRead(bytes: cf2)
        let action = try isotp.didRead(bytes: cf1)
        XCTAssertEqual(action, .waitForMore)
        XCTAssertEqual(isotp.state, .idle)

        let action2 = try isotp.didRead(bytes: cf3)
        XCTAssertEqual(action2, .waitForMore)
        XCTAssertEqual(isotp.state, .idle)

        let sf: [UInt8] = [0x02, 0x09, 0x02, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA]
        let action3 = try isotp.didRead(bytes: sf)
        XCTAssert(isotp.state == .idle)
        XCTAssertEqual(action3, .process(bytes: [0x09, 0x02]))
    }

    func testDroppedConsecutiveFrames() throws {
        
        let ff: [UInt8] = [0x10, 0x10, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let cf: [UInt8] = [0x21, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        let sf: [UInt8] = [0x02, 0x09, 0x02, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA]
        let isotp = UDS.ISOTP.Transceiver(behavior: .defensive)
        _ = try isotp.didRead(bytes: ff)
        _ = try isotp.didRead(bytes: cf)
        let action = try isotp.didRead(bytes: sf)
        XCTAssert(isotp.state == .idle)
        XCTAssertEqual(action, .process(bytes: [0x09, 0x02]))
    }
}
