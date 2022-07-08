//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
import CornucopiaCore
import Foundation
@_exported import Swift_UDS_Adapter

private var logger = Cornucopia.Core.Logger()

extension UDS {
    
    /// An encapsulation of a KWP 2000 Diagnostic Session, providing high level calls as per ISO 14230-3:2000
    public actor KWPDiagnosticSession {
        
        public let id: UDS.Header
        public let reply: UDS.Header
        public let pipeline: UDS.Pipeline
        public let mtu: Int

        public var activeTransferProgress: Progress?
        
        public init(with id: UDS.Header, replyAddress: UDS.Header, via pipeline: UDS.Pipeline) {
            self.id = id
            self.reply = replyAddress
            self.pipeline = pipeline
            self.mtu = pipeline.adapter.mtu
        }
        
        //MARK:- Direct KWP Requests

        /// Clear the stored DTC information
        @discardableResult
        public func clearDTC(group: GroupOfDTC = 0xFFFF) async throws -> UDS.GenericResponse {
            try await self.request(service: .kwpClearDiagnosticInformation(groupOfDTC: group))
        }

        /// Reset the ECU
        @discardableResult
        public func ecuReset(type: EcuResetType) async throws -> UDS.EcuResetResponse {
            try await self.request(service: .ecuReset(type: type))
        }
        
        /// Start a (non-default) diagnostic session
        /// NOTE: In constrast to UDS, KWP does not return the timing parameters in the positive respose. See ``accessTimingParameters``.
        @discardableResult
        public func start(type: DiagnosticSessionType) async throws -> UDS.GenericResponse {
            try await self.request(service: .diagnosticSessionControl(session: type))
        }
        
        /// Read data by local identifier
        @discardableResult
        public func readData(byLocalIdentifier id: UDS.DataIdentifier8) async throws -> UDS.DataIdentifier8Response {
            try await self.request(service: .kwpReadDataByLocalIdentifier(id: id))
        }

        /// Read DTC information
        @discardableResult
        public func readDTC(type: KWPReadDTCByStatusType, group: GroupOfDTC = 0xFFFF) async throws -> UDS.KWPDTCResponse {
            try await self.request(service: .kwpReadDTCByStatus(type: type, groupOfDTC: group))
        }
        
        /// Request the security access seed
        @discardableResult
        public func requestSeed(securityLevel: UDS.SecurityLevel) async throws -> UDS.SecurityAccessSeedResponse {
            try await self.request(service: .securityAccessRequestSeed(level: securityLevel))
        }
        
        /// Send the security access key
        @discardableResult
        public func sendKey(securityLevel: UDS.SecurityLevel, key: [UInt8]) async throws -> UDS.GenericResponse {
            try await self.request(service: .securityAccessSendKey(level: securityLevel, key: key))
        }
        
        /// Read ECU identification record
        @discardableResult
        public func readECU(identification: UDS.KWPECUIdentificationOption) async throws -> UDS.DataIdentifier8Response {
            try await self.request(service: .kwpReadEcuIdentification(id: identification))
        }
        
        /// Indicate tester being present
        @discardableResult
        public func testerPresent() async throws -> UDS.GenericResponse {
            try await self.request(service: .kwpTesterPresent)
        }

        //MARK:- Aggregated / Higher Level features
        public func readECUIdentification() async throws -> [UDS.KWPECUIdentificationOption: UDS.KWP.ECUIdentificationEntry] {
            let dataTable = try await self.readECU(identification: .dataTable)
            let scalingTable = try await self.readECU(identification: .scaling)
            let entries = try UDS.KWP.ECUIdentificationEntry.createFrom(dataTable: dataTable.dataRecord, scalingTable: scalingTable.dataRecord)
            return .init(uniqueKeysWithValues: entries.map { ($0.option, $0) })
        }
    }
}

//MARK:- Public Helpers
extension UDS.KWPDiagnosticSession {
    
    public func request<T: UDS.ConstructableViaMessage>(service: UDS.Service) async throws -> T {
        
        let message = try await self.pipeline.send(to: self.id, reply: self.reply, service: service)
        if message.bytes.count > 0, message.bytes[0] == UDS.NegativeResponse {
            let negativeResponseCode = UDS.NegativeResponseCode(rawValue: message.bytes[2]) ?? .undefined
            let error: UDS.Error = .udsNegativeResponse(code: negativeResponseCode)
            throw error
        }
        let response = T(message: message)
        return response
    }
}
