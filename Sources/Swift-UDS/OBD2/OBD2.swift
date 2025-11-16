//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
import Foundation

public extension UDS {

    enum OBD2 {

        public enum `Type` {
            case measurement
            case string
            case dtcs
            case custom
        }

        public enum VehicleInformation: UInt8 {
            case vin = 0x02
        }

        public enum CommonPids: UInt8 {
            case engineCoolantTemperature = 0x05
            case engineRPM = 0x0C
            case vehicleSpeed = 0x0D
            case standardsCompliance = 0x1C
            case fuelType = 0x51
        }

        public enum VehicleInformation: UInt8 {
            case vin = 0x02
            case calibrationId = 0x04
            case ecuName = 0x0A
        }

        public struct PID {
            let value: UInt8
            let type: UDS.OBD2.`Type`
            let parser: ([UInt8]) -> (Any)
        }

        static let pids: [UInt8: PID] = [
            VehicleInformation.vin.rawValue: PID(value: VehicleInformation.vin.rawValue, type: .string, parser: {
                // VIN response might have some garbage at the beginning
                guard let indexOfFirstLetter = $0.firstIndex(where: { Character(UnicodeScalar($0)).isLetter }) else { return "" }
                let vinData = $0[indexOfFirstLetter...]
                return String(bytes: vinData, encoding: .utf8) ?? ""
            }),
            CommonPids.engineRPM.rawValue: PID(value: CommonPids.engineRPM.rawValue, type: .measurement, parser: {
                let rpm = (Double($0[0]) * 256 + Double($0[1])) / 4
                return Measurement(value: rpm, unit: Unit(symbol: "rpm"))
            }),
            CommonPids.vehicleSpeed.rawValue: PID(value: CommonPids.vehicleSpeed.rawValue, type: .measurement, parser: {
                let speed = Double($0[0])
                return Measurement(value: speed, unit: UnitSpeed.kilometersPerHour)
            }),
            CommonPids.engineCoolantTemperature.rawValue: PID(value: CommonPids.engineCoolantTemperature.rawValue, type: .measurement, parser: {
                let temp = Double($0[0]) - 40
                return Measurement(value: temp, unit: UnitTemperature.celsius)
            }),
            CommonPids.standardsCompliance.rawValue: PID(value: CommonPids.standardsCompliance.rawValue, type: .custom, parser: {
                $0[0]
            }),
            CommonPids.fuelType.rawValue: PID(value: CommonPids.fuelType.rawValue, type: .custom, parser: {
                $0[0]
            }),
            VehicleInformation.calibrationId.rawValue: PID(value: VehicleInformation.calibrationId.rawValue, type: .string, parser: {
                String(bytes: $0, encoding: .utf8) ?? ""
            }),
            VehicleInformation.ecuName.rawValue: PID(value: VehicleInformation.ecuName.rawValue, type: .string, parser: {
                String(bytes: $0, encoding: .utf8) ?? ""
            }),
        ]
    }
}
