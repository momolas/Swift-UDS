import XCTest
@testable import Swift_UDS

final class ServiceIdsTests: XCTestCase {

    func testFuelTypePidConstant() {
        // PID 0x51 is Fuel Type. PID 0x52 is Ethanol fuel %.
        // The constant name 'fuelType' implies PID 0x51.
        XCTAssertEqual(UDS.CurrentPowertrainDiagnosticsDataType.fuelType, 0x51, "UDS.CurrentPowertrainDiagnosticsDataType.fuelType should be 0x51 (Fuel Type), but is 0x52.")
    }
}
