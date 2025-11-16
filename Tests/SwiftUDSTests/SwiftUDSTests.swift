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

    func testVINParsing() {
        let parser = UDS.OBD2.pids[UDS.OBD2.VehicleInformation.vin.rawValue]!.parser
        let vinBytes: [UInt8] = [0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48]
        let vin = parser(vinBytes) as! String
        XCTAssertEqual(vin, "123456789ABCDEFGH", "The VIN parsing is incorrect.")
    }

    func testEngineRPMParsing() {
        let parser = UDS.OBD2.pids[UDS.OBD2.CommonPids.engineRPM.rawValue]!.parser
        let rpmBytes: [UInt8] = [0x1A, 0x0A] // 6666 / 4 = 1666.5
        let rpm = parser(rpmBytes) as! Measurement<Unit>
        XCTAssertEqual(rpm.value, 1666.5, "The Engine RPM parsing is incorrect.")
    }

    func testVehicleSpeedParsing() {
        let parser = UDS.OBD2.pids[UDS.OBD2.CommonPids.vehicleSpeed.rawValue]!.parser
        let speedBytes: [UInt8] = [0x64] // 100 km/h
        let speed = parser(speedBytes) as! Measurement<UnitSpeed>
        XCTAssertEqual(speed.value, 100, "The Vehicle Speed parsing is incorrect.")
    }

    func testEngineCoolantTemperatureParsing() {
        let parser = UDS.OBD2.pids[UDS.OBD2.CommonPids.engineCoolantTemperature.rawValue]!.parser
        let tempBytes: [UInt8] = [0x82] // 90C
        let temp = parser(tempBytes) as! Measurement<UnitTemperature>
        XCTAssertEqual(temp.value, 90, "The Engine Coolant Temperature parsing is incorrect.")
    }

    func testStandardsComplianceParsing() {
        let parser = UDS.OBD2.pids[UDS.OBD2.CommonPids.standardsCompliance.rawValue]!.parser
        let complianceBytes: [UInt8] = [0x01]
        let compliance = parser(complianceBytes) as! UInt8
        XCTAssertEqual(compliance, 0x01, "The Standards Compliance parsing is incorrect.")
    }

    func testFuelTypeParsing() {
        let parser = UDS.OBD2.pids[UDS.OBD2.CommonPids.fuelType.rawValue]!.parser
        let fuelTypeBytes: [UInt8] = [0x01]
        let fuelType = parser(fuelTypeBytes) as! UInt8
        XCTAssertEqual(fuelType, 0x01, "The Fuel Type parsing is incorrect.")
    }

    func testCalibrationIdParsing() {
        let parser = UDS.OBD2.pids[UDS.OBD2.VehicleInformation.calibrationId.rawValue]!.parser
        let calIdBytes: [UInt8] = [0x41, 0x42, 0x43, 0x31, 0x32, 0x33]
        let calId = parser(calIdBytes) as! String
        XCTAssertEqual(calId, "ABC123", "The Calibration ID parsing is incorrect.")
    }

    func testEcuNameParsing() {
        let parser = UDS.OBD2.pids[UDS.OBD2.VehicleInformation.ecuName.rawValue]!.parser
        let ecuNameBytes: [UInt8] = [0x45, 0x4E, 0x47, 0x49, 0x4E, 0x45]
        let ecuName = parser(ecuNameBytes) as! String
        XCTAssertEqual(ecuName, "ENGINE", "The ECU Name parsing is incorrect.")
    }
}
