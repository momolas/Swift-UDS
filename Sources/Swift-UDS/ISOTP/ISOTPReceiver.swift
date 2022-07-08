//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//

@available(*, deprecated, message: "Please use the bi-directional ``ISOTPTransceiver``")
public extension UDS.ISOTP {
    
    /// A helper class for implementing an ISOTP reception state machine.
    /// Note: This is probably only of use for implementing (virtual) ECUs.
    final class Receiver {
        
        /// The Action after receiving another frame.
        @frozen public enum Action {
            /// Send a control flow frame
            case sendFlowControl(frame: FlowControlFrame)
            /// Wait for more frames
            case waitForMore
            /// Process the aggregated message
            case process(message: UDS.Message)
            /// Handle error
            case error(String)
        }
        
        /// The flow control frame.
        private let flowControlFrame: FlowControlFrame
        /// The flow control counter. When it hits 0, another flow control frame needs to be sent.
        private var flowControlCounter: UInt8 = 1
        /// The announced payload size from the FF.
        private var remainingPayloadCounter: Int = 0
        /// The current payload.
        private var payload: [UInt8] = []
        /// The aggregated message.
        private var message: UDS.Message {
            guard let first = self.messages.first else { fatalError("Message underflow") }
            return UDS.Message(id: first.id, reply: first.reply, bytes: payload)
        }
        /// The individual messages.
        private var messages: [UDS.Message] = []
        
        /// Initialize based on a desired block size and separation time.
        public init(blockSize: UInt8 = 0x20, separationTime: UInt8 = 0x00) {
            self.flowControlFrame = FlowControlFrame(blockSize: blockSize, separationTimeMs: separationTime)
        }
        
        /// Appends a frame. Returns the necessary action.
        public func received(frame: UDS.Message) -> Action {
            guard frame.bytes.count == UDS.ISOTP.FrameLength else { return .error("Invalid ISOTP frame length: \(frame.bytes.count), should be \(UDS.ISOTP.FrameLength)") }
            guard let frameType = FrameType(rawValue: frame.bytes[0] >> 4), frame.bytes[0] != 0x00 else {
                return .error("Invalid frame type w/ PCI \(frame.bytes[0], radix: .hex, prefix: true, toWidth: 2)")
            }
            self.messages.append(frame)
            switch frameType {

                case .single:
                    let dl = Int(frame.bytes[0] & 0x0F)
                    guard dl <= 7 else { return .error("Invalid FF PCI with payload length \(dl) > 7") }
                    let payload = Array(frame.bytes[1...dl])
                    let message = UDS.Message(id: frame.id, reply: frame.reply, bytes: payload)
                    return .process(message: message)
                    
                case .first:
                    let pciHi: UInt16 = UInt16(frame.bytes[0] & 0x0F)
                    let pciLo: UInt16 = UInt16(frame.bytes[1])
                    let pci = pciHi << 8 | pciLo
                    guard pci > 7 else { return .error("Invalid FF PCI with payload length \(pci) <= 7") }
                    self.remainingPayloadCounter = Int(pci - 6) // FF has 6 bytes of payload
                    self.payload += Array(frame.bytes.dropFirst(2))
                    self.flowControlCounter = self.flowControlFrame.blockSize
                    return .sendFlowControl(frame: self.flowControlFrame)
                    
                case .consecutive:
                    guard self.remainingPayloadCounter > 0 else { return .error("Received CF without FF") }
                    //let pciHi: UInt16 = UInt16(frame.bytes[0] & 0x0F)
                    //let pciLo: UInt16 = UInt16(frame.bytes[1])
                    //let pci = pciHi << 8 | pciLo
                    self.payload += Array(frame.bytes[1...min(7, self.remainingPayloadCounter)])
                    self.remainingPayloadCounter -= 7 // CF has a maximum of 7 bytes
                    if self.remainingPayloadCounter <= 0 {
                        return .process(message: self.message)
                    }
                    self.flowControlCounter -= 1
                    if flowControlCounter == 0 {
                        self.flowControlCounter = self.flowControlFrame.blockSize
                        return .sendFlowControl(frame: self.flowControlFrame)
                    } else {
                        return .waitForMore
                    }
            }
        }
    }
}
