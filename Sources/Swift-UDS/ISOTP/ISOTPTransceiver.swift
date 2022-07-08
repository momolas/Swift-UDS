//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//

extension UDS.ISOTP {

    /// A helper class for implementing an ISOTP state machine for receiving and transmitting.
    /// TODO:
    /// - [ ] Honor timing constraints: If there is more than 1s delay before between two expected frames, the state machine resets.
    /// - [ ] Implement standard ISOTP "defensive" failure handling: If there is a protocol violation, the state machine resets and, if the offending frame is a valid new start, tries to treat it as such.
    public final class Transceiver {

        /// The behavior on failure.
        @frozen public enum Behavior {
            /// This is the standardized behavior:
            /// If a frame would lead to a protocol violation, the state machine resets and tries to treat the offending frame as the beginning of a new message (SF or FF).
            case defensive
            /// This is the behavior for most of our unit tests:
            /// A frame that leads to a protocol violation throws an error and leaves the state machine unreset.
            case strict
        }
        
        /// The State of the Union, err..., Machine.
        @frozen public enum State {
            /// Neither in a multiframe reception nor transmission state.
            case idle
            /// During a multiframe send
            case sending
            /// During a multiframe receive
            case receiving
        }

        /// The client action.
        @frozen public enum Action: Equatable {
            /// The complete message has been assembled and is ready to be processed.
            case process(bytes: [UInt8])
            /// Write one or more frames. Separation time is given in milliseconds.
            /// If only one frame is given, you can rely on `separationTime` being set to 0.
            case writeFrames(_ frames: [[UInt8]], separationTime: UInt8, isLastBatch: Bool)
            /// Nothing to do, e.g., when we need more frames to process, or – in `defensive` mode – a violation has occured and the offending frame is neither an SF or FF.
            case waitForMore
        }

        /// Protocol errors
        @frozen public enum Error: Swift.Error {
            case messageTooSmall
            case messageTooBig
            case protocolViolation(reason: String)
        }

        /// Create the transceiver.
        public init(behavior: Behavior = .defensive, blockSize: UInt8 = 0x00, separationTimeMs: UInt8 = 0x00) {
            self.behavior = behavior
            self.flowControlFrame = FlowControlFrame(flowStatus: .clearToSend, blockSize: blockSize, separationTimeMs: separationTimeMs)
        }

        /// Call this for sending anything.
        public func write(bytes: [UInt8]) throws -> Action {
            guard bytes.count <= UDS.ISOTP.MaximumFrameSize else { throw Error.messageTooBig }
            guard bytes.count > 7 else {
                // Nothing more to do for single frames – we can leave the state in `idle`
                let frame = [UInt8(bytes.count)] + bytes
                return .writeFrames([frame], separationTime: 0, isLastBatch: true)
            }

            let pcihi: UInt8 = (FrameType.first.rawValue << 4) | UInt8(bytes.count >> 8)
            let pcilo: UInt8 = UInt8(bytes.count & 0x0FF)
            let payload = bytes[...5]
            self.writingPayload = bytes[6...]
            self.sequenceNumber = 0x01
            // We now transition into the multiframe sending phase
            self.state = .sending
            let frame = [pcihi, pcilo] + payload
            return .writeFrames([frame], separationTime: 0, isLastBatch: false)
        }

        /// Call this after receiving a single frame.
        public func didRead(bytes: [UInt8]) throws -> Action {
            guard bytes.count == UDS.ISOTP.FrameLength else { throw Self.Error.protocolViolation(reason: "Invalid ISOTP frame length: \(bytes.count), should be \(UDS.ISOTP.FrameLength)") }
            
            // Strict behavior
            guard self.behavior == .defensive else {
                switch self.state {
                    case .sending:
                        return try self.parseFlowControlFrame(bytes: bytes)
                    case .idle, .receiving:
                        return try self.parseDataFrame(bytes: bytes)
                }
            }
            
            // Defensive behavior
            do {
                switch self.state {
                    case .sending:
                        return try self.parseFlowControlFrame(bytes: bytes)
                    case .idle, .receiving:
                        return try self.parseDataFrame(bytes: bytes)
                }
            } catch Error.protocolViolation(_) {
                // reset and try again
                self.reset()
                do {
                    return try self.parseDataFrame(bytes: bytes)
                } catch {
                    // reset again and ignore the frame
                    self.reset()
                    return .waitForMore
                }
            } catch {
                throw error
            }
        }

        public var state: State = .idle

        //MARK: private
        private let behavior: Behavior
        private let flowControlFrame: FlowControlFrame
        // for writing
        private var writingPayload: ArraySlice<UInt8> = []
        private var sequenceNumber: UInt8 = 0
        // for reading
        private var readingPayload: [UInt8] = []
        private var remainingPayloadCounter = 0
        private var flowControlCounter: UInt8 = 0
        
        /// Reset, i.e., after a protocol violation
        private func reset() {
            self.state = .idle
            self.writingPayload = []
            self.sequenceNumber = 0

            self.readingPayload = []
            self.remainingPayloadCounter = 0
            self.flowControlCounter = 0
        }

        /// Handle next flow control
        private func parseFlowControlFrame(bytes: [UInt8]) throws -> Action {
            guard let flowControlFrame = FlowControlFrame(from: bytes) else {
                self.reset()
                throw Transceiver.Error.protocolViolation(reason: "Did not receive a flow control frame during sending")
            }
            let numberOfUnconfirmedFrames = (flowControlFrame.blockSize == 0) ? Int.max : Int(flowControlFrame.blockSize)

            var nextFrames: [[UInt8]] = []
            for _ in 0..<numberOfUnconfirmedFrames {
                let pci = (FrameType.consecutive.rawValue << 4) | self.sequenceNumber & 0x0F
                let nextUpTo7 = min(7, self.writingPayload.count)
                let payload = self.writingPayload[self.writingPayload.startIndex..<self.writingPayload.startIndex+nextUpTo7]
                self.writingPayload = self.writingPayload.dropFirst(nextUpTo7)
                let frameBytes = [pci] + payload
                nextFrames.append(frameBytes)
                guard !self.writingPayload.isEmpty else { break }
                self.sequenceNumber = (self.sequenceNumber + 1) % 16
            }
            if self.writingPayload.isEmpty {
                self.reset()
            }
            return .writeFrames(nextFrames, separationTime: flowControlFrame.separationTime, isLastBatch: self.writingPayload.isEmpty)
        }

        /// Handle next data frame
        private func parseDataFrame(bytes: [UInt8]) throws -> Action {
            guard let frameType = FrameType(rawValue: bytes[0] >> 4), bytes[0] != 0x00 else {
                throw Transceiver.Error.protocolViolation(reason: "Invalid frame type w/ PCI \(bytes[0], radix: .hex, prefix: true, toWidth: 2)")
            }
            switch frameType {

                case .single:
                    guard self.state == .idle else { throw Transceiver.Error.protocolViolation(reason: "Did receive SF while not being .idle") }
                    let dl = Int(bytes[0] & 0x0F)
                    guard dl <= 7 else { throw Transceiver.Error.protocolViolation(reason: "Invalid SF PCI with payload length \(dl) > 7") }
                    let payload = Array(bytes[1...dl])
                    // Nothing more to do for single frames – we can leave the state in `idle`
                    return .process(bytes: payload)

                case .first:
                    guard self.state == .idle else { throw Transceiver.Error.protocolViolation(reason: "Did receive FF while not being .idle") }
                    let pciHi: UInt16 = UInt16(bytes[0] & 0x0F)
                    let pciLo: UInt16 = UInt16(bytes[1])
                    let pci = pciHi << 8 | pciLo
                    guard pci > 7 else { throw Transceiver.Error.protocolViolation(reason: "Invalid FF PCI with payload length \(pci) <= 7") }
                    self.remainingPayloadCounter = Int(pci - 6) // FF has 6 bytes of payload
                    self.readingPayload += Array(bytes.dropFirst(2))
                    self.flowControlCounter = self.flowControlFrame.blockSize
                    self.state = .receiving
                    self.sequenceNumber = 1
                    let frame = self.flowControlFrame.bytes
                    return .writeFrames([frame], separationTime: 0, isLastBatch: false)

                case .consecutive:
                    guard self.state == .receiving else { throw Transceiver.Error.protocolViolation(reason: "Did receive CF while not being .receiving") }
                    let sn: UInt8 = bytes[0] & 0xF
                    guard sn == self.sequenceNumber else { throw Transceiver.Error.protocolViolation(reason: "Received CF with sequence number \(sn), was expecting \(self.sequenceNumber)") }
                    self.sequenceNumber = (self.sequenceNumber + 1) % 16
                    self.readingPayload += Array(bytes[1...min(7, self.remainingPayloadCounter)])
                    self.remainingPayloadCounter -= 7 // CF has a maximum of 7 bytes
                    if self.remainingPayloadCounter <= 0 {
                        self.state = .idle
                        defer { self.reset() }
                        return .process(bytes: self.readingPayload)
                    }
                    guard self.flowControlFrame.blockSize > 0 else { return .waitForMore }

                    self.flowControlCounter -= 1
                    if flowControlCounter == 0 {
                        self.flowControlCounter = self.flowControlFrame.blockSize
                        let frame = self.flowControlFrame.bytes
                        return .writeFrames([frame], separationTime: 0, isLastBatch: false)
                    } else {
                        return .waitForMore
                    }
            }
        }
    }
}

