//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
import CornucopiaCore

private let logger = Cornucopia.Core.Logger()

public extension UDS.KWP {

    struct ECUIdentificationEntry {

        public enum ScalingDataType: UInt8 {

            case unSignedNumeric
            case signedNumeric
            case bitMappedReportedWithOutMask
            case bitMappedReportedWithMask
            case binaryCodedDecimal
            case stateEncodedVariable
            case ascii
            case signedFloatingPoint
            case packet
            case formula
            case unitOrFormat
            case vehicleManufacturerSpecificC
            case vehicleManufacturerSpecificD
            case vehicleManufacturerSpecificE
            case reserved
        }

        public let option: UDS.KWPECUIdentificationOption
        public let type: ScalingDataType
        public let data: UDS.DataRecord

        public init(option: UDS.KWPECUIdentificationOption, type: ScalingDataType, data: UDS.DataRecord) {
            self.option = option
            self.type = type
            self.data = data
        }

        public static func createFrom(dataTable: UDS.DataRecord, scalingTable: UDS.DataRecord) throws -> [ECUIdentificationEntry] {

            guard !dataTable.isEmpty else { return [] }
            guard scalingTable.count > 2 else { return [] }

            var dataIndex = dataTable.startIndex
            var scalingIndex = scalingTable.startIndex
            var entries: [ECUIdentificationEntry] = []

            while true {

                let nextOffset = Int(scalingTable[scalingIndex])
                guard nextOffset != 0xFF else { break }

                let option = scalingTable[scalingIndex.advanced(by: 1)]
                var payload: [UInt8] = []
                var dataTypes: Set<ScalingDataType> = .init()

                var scalingEntryIndex = scalingIndex.advanced(by: 2)
                formatLoop: while scalingEntryIndex < scalingIndex.advanced(by: nextOffset) {
                    let formatByte = scalingTable[scalingEntryIndex]
                    logger.trace("handling format byte \(formatByte, radix: .hex, prefix: true, toWidth: 2) in option \(option, radix: .hex, prefix: true, toWidth: 2)")
                    let dataType = ScalingDataType(rawValue: formatByte >> 4)!
                    var dataLength = Int(formatByte & 0xF)
                    scalingEntryIndex = scalingEntryIndex.advanced(by: 1)

                    if dataLength == 0 {
                        dataLength = Int(scalingTable[scalingEntryIndex])
                        scalingEntryIndex = scalingEntryIndex.advanced(by: 1)
                    }

                    let payloadSlice = dataTable[dataIndex..<dataIndex.advanced(by: dataLength)]
                    dataTypes.insert(dataType)
                    switch dataType {
                        case .ascii:
                            logger.trace("ascii part found '\(Array(payloadSlice).CC_asciiDecodedString)'")

                        case .formula:
                            logger.trace("formula found, skipping the rest for now")
                            break formatLoop

                        default:
                            logger.trace("unhandled data type '\(dataType)'")

                    }
                    payload += payloadSlice
                    dataIndex = dataIndex.advanced(by: dataLength)
                }
                let dataType: ScalingDataType

                switch dataTypes.count {
                    case 0: throw UDS.Error.internal(string: "Invariant violated")
                    case 1: dataType = dataTypes.first!
                    default:
                        logger.debug("Warning: ECU identification with mixed data type slices found. Setting to 'reserved'")
                        dataType = .reserved
                }

                let entry = ECUIdentificationEntry(option: option, type: dataType, data: payload)
                entries.append(entry)

                logger.trace("Parameter \(option, radix: .hex, prefix: true, toWidth: 2) = \(payload, radix: .hex, prefix: true, toWidth: 2, separator: " ")")
                scalingIndex = scalingIndex.advanced(by: nextOffset)
            }
            return entries
        }
    }
}
