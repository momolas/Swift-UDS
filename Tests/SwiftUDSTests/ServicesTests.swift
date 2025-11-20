import XCTest
@testable import Swift_UDS

final class ServicesTests: XCTestCase {

    func testRequestDownloadPayload() {
        // address: 2 bytes, length: 3 bytes
        // ALFID should be (length.count << 4) | address.count = (3 << 4) | 2 = 0x32
        let address: [UInt8] = [0x10, 0x00]
        let length: [UInt8] = [0x00, 0x01, 0x00]
        let service = UDS.Service.requestDownload(compression: 0, encryption: 0, address: address, length: length)

        let payload = service.payload
        // Expected payload:
        // SID (0x34)
        // DFI (0x00)
        // ALFID (0x32)
        // Address [0x10, 0x00]
        // Length [0x00, 0x01, 0x00]
        let expected: [UInt8] = [0x34, 0x00, 0x32, 0x10, 0x00, 0x00, 0x01, 0x00]

        XCTAssertEqual(payload, expected, "The payload for requestDownload has incorrect ALFID calculation.")
    }

    func testRequestUploadPayload() {
        // address: 4 bytes, length: 2 bytes
        // ALFID should be (length.count << 4) | address.count = (2 << 4) | 4 = 0x24
        let address: [UInt8] = [0x00, 0x00, 0x10, 0x00]
        let length: [UInt8] = [0x01, 0x00]
        let service = UDS.Service.requestUpload(compression: 0, encryption: 0, address: address, length: length)

        let payload = service.payload
        // Expected payload:
        // SID (0x35)
        // DFI (0x00)
        // ALFID (0x24)
        // Address [0x00, 0x00, 0x10, 0x00]
        // Length [0x01, 0x00]
        let expected: [UInt8] = [0x35, 0x00, 0x24, 0x00, 0x00, 0x10, 0x00, 0x01, 0x00]

        XCTAssertEqual(payload, expected, "The payload for requestUpload has incorrect ALFID calculation.")
    }
}
