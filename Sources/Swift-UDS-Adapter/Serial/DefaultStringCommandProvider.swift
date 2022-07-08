//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
import Swift_UDS

public extension UDS.GenericSerialAdapter {

    /// This is the default string command provider with support for most of the AT commands
    /// found in typical serial OBD2 adapters, such as the ELM327.
    struct DefaultStringCommandProvider: StringCommandProvider {

        public var headerLengthInCharacters: Int = -1

        static let responseConverterString: ResponseConverter = { stringResponse, _ in
            guard !stringResponse.isEmpty else { return .failure(.noResponse) }
            guard !stringResponse.contains("?") else { return .failure(.unrecognizedCommand) }
            return Result.success(stringResponse.CC_trimmed())
        }

        static let responseConverterBool: ResponseConverter = { stringResponse, _ in
            guard !stringResponse.isEmpty else { return .failure(.noResponse) }
            guard !stringResponse.contains("?") else { return .failure(.unrecognizedCommand) }
            // Better use `hasSuffix` here to compensate for leading "garbage" thanks to ATE=1
            let ok = stringResponse.CC_trimmed().hasSuffix("OK")
            return Result.success(ok)
        }

        static let responseConverterVoltage: ResponseConverter = { stringResponse, _ in
            guard !stringResponse.isEmpty else { return .failure(.noResponse) }
            guard !stringResponse.contains("?") else { return .failure(.unrecognizedCommand) }
            var voltage = stringResponse.CC_trimmed()
            if voltage.hasSuffix("V") { _ = voltage.dropLast() }
            guard let double = Double(voltage) else { return .failure(.invalidCharacters) }
            return Result.success(double)
        }

        static let responseConverterSupported: ResponseConverter = { stringResponse, _ in
            guard !stringResponse.isEmpty else { return .failure(.noResponse) }
            guard !stringResponse.contains("?") else { return .failure(.unrecognizedCommand) }
            return Result.success(stringResponse.CC_trimmed())
        }

        static let responseConverterBusProtocol: ResponseConverter = { stringResponse, _ in
            guard !stringResponse.isEmpty else { return .failure(.noResponse) }
            guard !stringResponse.contains("?") else { return .failure(.unrecognizedCommand) }
            let last = String(stringResponse.CC_trimmed().last!)
            let proto = UDS.BusProtocol(rawValue: last) ?? .unknown
            return Result.success(proto)
        }

        static let responseConverterEcuDetection: ResponseConverter = { stringResponse, _ in
            guard !stringResponse.isEmpty else { return .failure(.noResponse) }
            var ecuLines: [String] = []
            for line in stringResponse.CC_asLines() {
                if line.localizedStandardContains("ERROR") || line.localizedStandardContains("UNABLE") {
                    let busError = UDS.Error.busError(string: line.CC_trimmed())
                    return .failure(busError)
                }
                guard line.atIsLineFromECU else { continue }
                let trimmed = line.CC_trimmed()
                guard !trimmed.isEmpty else { continue }
                ecuLines.append(trimmed)
            }
            return Result.success(ecuLines)
        }

        static let responseConverterSTPX: ResponseConverter = { stringResponse, _ in
            guard !stringResponse.isEmpty else { return .failure(.noResponse) }
            guard !stringResponse.contains("?") else { return .failure(.unrecognizedCommand) }
            let trimmedStringResponse = stringResponse.CC_trimmed()
            guard trimmedStringResponse == "DATA" else { return .failure(.busError(string: stringResponse)) }
            return Result.success(())
        }

        static let responseConverterData: ResponseConverter = { (stringResponse, adapter) in
            guard !stringResponse.isEmpty else { return .failure(.noResponse) }
            var messages: [UDS.Message] = []
            var error: String = ""
            stringResponse.enumerateLines { (line, stop: inout Bool) in
                let trimmed = line.CC_trimmed()
                guard trimmed.atIsLineFromECU else {
                    error = trimmed
                    stop = true
                    return
                }
                guard trimmed.count >= adapter.numberOfHeaderCharacters + 2 else { return }
                let header = UDS.Header(String(trimmed[0..<adapter.numberOfHeaderCharacters]), radix: 16) ?? 0
                let data = String(trimmed[adapter.numberOfHeaderCharacters..<trimmed.count]).CC_hexDecodedUInt8Array
                let message: UDS.Message = .init(id: header, bytes: data)
                messages.append(message)
            }
            guard error.isEmpty else {
                return .failure(.busError(string: error))
            }
            return Result.success(messages)
        }

        public func provide(command: UDS.GenericSerialAdapter.StringCommand) -> (string: String, responseConverter: ResponseConverter)? {

            switch command {

                // basic (ELM327 and clones)
                case .adaptiveTiming(let on):
                    return ("ATAT\(on.atValue)", Self.responseConverterBool)
                case .allowLongMessages(let on):
                    return (on ? "ATAL" : "ATNL", Self.responseConverterBool)
                case .canAutoFormat(let on):
                    return ("ATCAF\(on.atValue)", Self.responseConverterBool)
                case .canReceiveArbitration(let id):
                    let address = id < 0x800 ? String(format: "%03X", id) : String(format: "%08X", id)
                    return ("ATCRA\(address)", Self.responseConverterBool)
                case .connect:
                    return ("0100", Self.responseConverterEcuDetection)
                case .describeProtocolNumeric:
                    return ("ATDPN", Self.responseConverterBusProtocol)
                case .describeProtocolTextual:
                    return ("ATDP", Self.responseConverterString)
                case .dummy:
                    return (".", Self.responseConverterString) // not really, but we only care about error or not
                case .echo(let on):
                    return ("ATE\(on.atValue)", Self.responseConverterBool)
                case .identify:
                    return ("ATI", Self.responseConverterString)
                case .linefeed(let on):
                    return ("ATL\(on.atValue)", Self.responseConverterBool)
                case .readVoltage:
                    return ("ATRV", Self.responseConverterVoltage)
                case .reset:
                    return ("ATZ", Self.responseConverterString)
                case .setHeader(let id):
                    let address = id < 0x800 ? String(format: "%03X", id) : String(format: "%08X", id)
                    return ("ATSH\(address)", Self.responseConverterBool)
                case .setProtocol(let proto):
                    return ("ATSP\(proto.rawValue)", Self.responseConverterBool)
                case .setTimeout(let value):
                    let timeout = String(format: "%02X", value)
                    return ("ATST\(timeout)", Self.responseConverterBool)
                case .showHeaders(let on):
                    return ("ATH\(on.atValue)", Self.responseConverterBool)
                case .spaces(let on):
                    return ("ATS\(on.atValue)", Self.responseConverterBool)
                case .tryProtocol(let proto):
                    return ("ATTP\(proto.rawValue)", Self.responseConverterBool)
                case .version1:
                    return ("AT@1", Self.responseConverterString)
                case .version2:
                    return ("AT@2", Self.responseConverterString)

                // extended (STN11xx, STN22xx)
                case .stnCanSegmentationAddSeparationTime(var ms):
                    if ms < 0 { ms = 0 }
                    else if ms > 127 { ms = 127 }
                    return ("STCSTM\(ms)", Self.responseConverterBool)
                case .stnCanSegmentationReceive(let on):
                    return ("STCSEGR\(on.atValue)", Self.responseConverterBool)
                case .stnCanSegmentationTimeouts(let fc, let cf):
                    return ("STCTOR\(fc),\(cf)", Self.responseConverterBool)
                case .stnCanSegmentationTransmit(let on):
                    return ("STCSEGT\(on.atValue)", Self.responseConverterBool)

                case .stnTransmitAnnounce(let header, let count, let expectedResponseCount):
                    var parameters: [String] = []
                    if let header = header {
                        parameters.append("h:\(header, radix: .hex)")
                    }
                    if let expectedResponseCount = expectedResponseCount {
                        parameters.append("r:\(expectedResponseCount)")
                    }
                    parameters.append("l:\(count)")
                    let string = parameters.joined(separator: ",")
                    return ("STPX\(string)", Self.responseConverterSTPX)
                case .stnDeviceIdentify:
                    return ("STDI", Self.responseConverterString)
                case .stnExtendedIdentify:
                    return ("STIX", Self.responseConverterString)
                case .stnIdentify:
                    return ("STI", Self.responseConverterString)
                case .stnProtocolTimeout(let ms):
                    return ("STPTO\(ms)", Self.responseConverterBool)
                case .stnSerialNumber:
                    return ("STSN", Self.responseConverterString)

                // extended (UniCarScan)
                case .unicarsIdentify:
                    return ("AT#1", Self.responseConverterString)

                // internal / meta
                case .probeAutoSegmentation:
                    return ("ff11223344556677889900", Self.responseConverterSupported)
                case .probeFullFrameNoResponse:
                    return ("07ff1122334455660", Self.responseConverterSupported)
                case .probeSmallFrameNoResponse:
                    return ("ff000", Self.responseConverterSupported)

                // uds
                case .data(let bytes, let expectedResponseCount):
                    guard expectedResponseCount == nil || 0...15 ~= expectedResponseCount! else { return nil }
                    var string = bytes.map { String(format: "%02X", $0) }.joined()
                    if let expectedResponseCount = expectedResponseCount {
                        string += String(format: "%X", expectedResponseCount)
                    }
                    return (string, Self.responseConverterData)
                case .test(let bytes):
                    let string = bytes.map { String(format: "%02X", $0) }.joined()
                    return (string, Self.responseConverterEcuDetection)
            }
        }
    }
}

