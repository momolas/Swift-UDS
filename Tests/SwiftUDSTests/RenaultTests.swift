import XCTest
@testable import Swift_UDS

final class RenaultTests: XCTestCase {

    func testRenaultDIDs() {
        // Verify that we can access the Renault DIDs
        let odometer = UDS.Renault.DID.odometer
        XCTAssertEqual(odometer.rawValue, 0xF40D, "Renault DID Odometer should be 0xF40D")
    }

    func testReadDataByLocalIdentifierPayload() {
        // Test Service 0x21
        let localId: UInt8 = 0x10
        let service = UDS.Service.readDataByLocalIdentifier(id: localId)

        let payload = service.payload
        // 0x21 is kwpReadDataByLocalIdentifier
        let expected: [UInt8] = [0x21, 0x10]

        XCTAssertEqual(payload, expected, "The payload for readDataByLocalIdentifier is incorrect.")
    }
}
