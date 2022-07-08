//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
import CornucopiaCore
import Foundation

public extension UDS {

    /// A UDS Message.
    /// A UDS Message consists of one or two headers and a number of bytes.
    /// Depending on the _direction_ of the message, the ``id`` and ``reply`` is to be interpretated differently:
    /// If the message is outgoing, the `id` indicates the suggested receiver of the message and the `reply` indicates the reply (sic!) address.
    /// If the message is incoming, the `id` indicates the reply address and the `reply`, if set, indicates the possible originator.
    /// Irrespective of the direction, the concept of the UDS message headers does not necessarily apply to a
    /// one-to-one request/response structure. After all, it's a broadcast bus and apart from the functional addressing in OBD2 (e.g. 0x7DF -> 0x7E0 / 0x7E8)
    /// the physical address space is pretty much vendor specific.
    struct Message: Equatable {
        
        /// The request arbitration id controls the suggested receiver of this message.
        public let id: UDS.Header
        /// The expected reply id. Often, this is the UDS.Header with the 4th bit set (`| 1 << 4`)
        public let reply: UDS.Header
        /// The message payload
        public var bytes: [UInt8]
        
        /// The service identifier
        public var sid: UInt8 { self.bytes.first! }
        
        public init(id: UDS.Header, reply: UDS.Header = 0, bytes: [UInt8]) {
            self.id = id
            self.reply = reply
            self.bytes = bytes
        }
        
        /// Create a response message (id and reply headers are swapped) with the specified payload.
        public func response(bytes: [UInt8]) -> Self {
            .init(id: self.reply, bytes: bytes)
        }
        
        /// Create a 'response pending' intermediate message.
        public func responsePending() -> Self {
            .init(id: self.reply, bytes: [UDS.NegativeResponse, self.sid, UDS.NegativeResponseCode.requestCorrectlyReceivedResponsePending.rawValue])
        }
        
        /// Create a negative response with the specified code.
        public func negativeResponse(nrc: UDS.NegativeResponseCode) -> Self {
            .init(id: self.reply, bytes: [UDS.NegativeResponse, self.sid, nrc.rawValue])
        }
        
        /// Create a message with the same adresss fields, but different payload.
        public func with(bytes: [UInt8]) -> Self {
            .init(id: self.id, reply: self.reply, bytes: bytes)
        }
        
        /// Create a message altering the replyId
        public func with(replyId: UDS.Header) -> Self {
            .init(id: self.id, reply: replyId, bytes: self.bytes)
        }
    }
}

extension UDS.Message: CustomStringConvertible {
    
    public var description: String {
        
        let id = "\(self.id, radix: .hex)"
        let endIndex = min(self.bytes.endIndex, 16)
        let bytes: [UInt8] = Array(self.bytes[0..<endIndex])
        let message = "\(bytes, radix: .hex, toWidth: 2)"
        let truncated = endIndex < self.bytes.endIndex ? " (...)" : ""
        return "\(id) [\(bytes.count)] \(message)\(truncated)"
    }
}
