import XCTest
@testable import Swift_UDS

final class SwiftUDSTests: XCTestCase {

    func testDiagnosticSessionControlPayload() {
        let service = UDS.Service.diagnosticSessionControl(session: .extended)
        let payload = service.payload
        XCTAssertEqual(payload, [0x10, 0x03], "The payload for diagnosticSessionControl is incorrect.")
    }

    func testEcuResetPayload() {
        let service = UDS.Service.ecuReset(type: .hardReset)
        let payload = service.payload
        XCTAssertEqual(payload, [0x11, 0x01], "The payload for ecuReset is incorrect.")
    }

    func testReadDataByIdentifierPayload() {
        let service = UDS.Service.readDataByIdentifier(id: 0x1234)
        let payload = service.payload
        XCTAssertEqual(payload, [0x22, 0x12, 0x34], "The payload for readDataByIdentifier is incorrect.")
    }

    func testWriteDataByIdentifierPayload() {
        let service = UDS.Service.writeDataByIdentifier(id: 0x5678, drec: [0xDE, 0xAD, 0xBE, 0xEF])
        let payload = service.payload
        XCTAssertEqual(payload, [0x2E, 0x56, 0x78, 0xDE, 0xAD, 0xBE, 0xEF], "The payload for writeDataByIdentifier is incorrect.")
    }

    func testRequestUploadPayload() {
        let service = UDS.Service.requestUpload(compression: 0, encryption: 0, address: [0x12, 0x34], length: [0x56, 0x78])
        let payload = service.payload
        XCTAssertEqual(payload, [0x35, 0x00, 0x22, 0x12, 0x34, 0x56, 0x78], "The payload for requestUpload is incorrect.")
    }
}
