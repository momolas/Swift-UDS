//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//

public extension UDS.ISOTP {

    /// ISOTP frame length for CAN-2.0.
    static let FrameLength = 8

    /// The flow control status.
    enum FlowStatus: UInt8 {
        /// Clear to send more frames.
        case clearToSend    = 0x30
        /// Buffer full, please wait for another control flow frame with `clearToSend`.
        case wait           = 0x31
        /// Overflow, please abort and resend the whole command.
        case overflow       = 0x32
    }
    
    /// The ISOTP frame type.
    enum FrameType: UInt8 {
        case single         = 0x00
        case first          = 0x01
        case consecutive    = 0x02
    }
    
    /// A flow control frame.
    struct FlowControlFrame {
        public let flowStatus: FlowStatus
        public let blockSize: UInt8
        public let separationTime: UInt8
        public var bytes: [UInt8] { [self.flowStatus.rawValue, self.blockSize, self.separationTime] }
        
        public init(flowStatus: FlowStatus = .clearToSend, blockSize: UInt8 = 0x20, separationTimeMs: UInt8 = 0x0) {
            self.flowStatus = flowStatus
            self.blockSize = blockSize
            self.separationTime = separationTimeMs
        }
        
        public init?(from message: UDS.Message) {
            guard message.bytes.count >= 3 else { return nil }
            guard let flowStatus = FlowStatus(rawValue: message.bytes[0]) else { return nil }
            self.flowStatus = flowStatus
            self.blockSize = message.bytes[1]
            self.separationTime = message.bytes[2]
        }

        public init?(from bytes: [UInt8]) {
            guard bytes.count >= 3 else { return nil }
            guard let flowStatus = FlowStatus(rawValue: bytes[0]) else { return nil }
            self.flowStatus = flowStatus
            self.blockSize = bytes[1]
            self.separationTime = bytes[2]
        }
    }
}
