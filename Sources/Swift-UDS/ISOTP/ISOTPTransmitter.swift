//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//

@available(*, deprecated, message: "Please use the bi-directional ``ISOTPTransceiver``")
public extension UDS.ISOTP {
    
    /// A helper class for implementing an ISOTP transmission state machine.
    /// Note: This is probably only of use for implementing (virtual) ECUs.
    final class Transmitter {
        
        /// The action when starting to process a response or a flow control frame.
        @frozen public enum Action {
            /// Response fits into a single frame. No encoding necessary.
            case sendSingleFrame(bytes: [UInt8])
            /// Response will be encoded into multiple frames. This is the first one.
            case sendFirstFrame(bytes: [UInt8])
            /// Send consecutive frames of a multi-frame response.
            case sendConsecutive(frames: [[UInt8]], separationTime: UInt8, isLastBatch: Bool)
            /// An error occured.
            case error(String)
        }

        /// The response header. It's here solely for consumers to remember. The `Transmitter` itself does not use it.
        public let id: UDS.Header
        /// The current pending payload.
        var pendingPayload: ArraySlice<UInt8> = []
        /// The current ISOTP sequence number.
        var sequenceNumber: UInt8 = 0
        
        /// Create a transmitter.
        public init(id: UDS.Header) {
            self.id = id
        }

        /// Start processing by adding a (response) message to be encoded.
        public func addMessage(_ message: UDS.Message) -> Transmitter.Action {
            guard message.bytes.count > 7 else {
                let payload: [UInt8] = [UInt8(message.bytes.count)] + message.bytes
                return .sendSingleFrame(bytes: payload)
            }
            
            guard message.bytes.count <= UDS.ISOTP.MaximumFrameSize else { fatalError("Message too big (>= 4095 bytes)")}
            
            let pcihi: UInt8 = (FrameType.first.rawValue << 4) | UInt8(message.bytes.count >> 8)
            let pcilo: UInt8 = UInt8(message.bytes.count & 0x0FF)
            let payload = message.bytes[...5]
            self.pendingPayload = message.bytes[6...]
            self.sequenceNumber = 0x01
            return .sendFirstFrame(bytes: [pcihi, pcilo] + payload)
        }

        /// Call, when a flow control frame has been received.
        public func received(flowControlBytes: [UInt8]) -> Action {
            guard flowControlBytes.count == UDS.ISOTP.FrameLength else { return .error("Invalid ISOTP frame length: \(flowControlBytes.count), should be \(UDS.ISOTP.FrameLength)") }

            let frameType = (flowControlBytes[0] & 0xF0) >> 4
            guard frameType == 3 else { return .error("Not a Flow Control Flame w/ FT \(frameType) != 3") }
            
            let blockSize = flowControlBytes[1]
            let minST = flowControlBytes[2]
            let numberOfUnconfirmedFrames = (blockSize == 0) ? Int.max : Int(blockSize)
            
            var nextFrames: [[UInt8]] = []
            for _ in 0..<numberOfUnconfirmedFrames {
                let pci = (FrameType.consecutive.rawValue << 4) | self.sequenceNumber & 0x0F
                let nextUpTo7 = min(7, self.pendingPayload.count)
                let payload = self.pendingPayload[self.pendingPayload.startIndex..<self.pendingPayload.startIndex+nextUpTo7]
                self.pendingPayload = self.pendingPayload.dropFirst(nextUpTo7)
                let frameBytes = [pci] + payload
                nextFrames.append(frameBytes)
                
                guard !self.pendingPayload.isEmpty else { break }
                
                sequenceNumber += 1
                if sequenceNumber == 16 {
                    sequenceNumber = 0
                }
            }
            return .sendConsecutive(frames: nextFrames, separationTime: minST, isLastBatch: self.pendingPayload.isEmpty)
        }
    }
}
