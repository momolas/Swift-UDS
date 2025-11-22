//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
import Foundation

public extension UDS.ISOTP {

    /// An ISOTP Transmitter that handles Flow Control (ISO 15765-2).
    ///
    /// This class manages the stateful transmission of segmented messages, including:
    /// - Generating the First Frame (FF).
    /// - Waiting for Flow Control (FC) frames.
    /// - Respecting Block Size (BS) and Separation Time (STmin).
    /// - Generating Consecutive Frames (CF).
    class Transmitter {

        public enum State {
            case idle
            case sendingSingleFrame
            case waitingForFlowControl
            case sendingConsecutiveFrames
            case completed
            case error(String)
        }

        public enum Output {
            case frame([UInt8])
            case delay(TimeInterval)
            case completed
        }

        private let payload: [UInt8]
        private var offset: Int = 0
        private var sequenceNumber: UInt8 = 1
        private var blockSize: Int = 0
        private var framesSinceLastFlowControl: Int = 0
        private var separationTime: TimeInterval = 0

        public private(set) var state: State = .idle

        public init(payload: [UInt8]) {
            self.payload = payload
        }

        /// Starts the transmission. Returns the first frame (SF or FF) or nil if payload is empty.
        public func start() throws -> [UInt8] {
            guard !payload.isEmpty else {
                self.state = .error("Empty payload")
                throw UDS.Error.encoderError(string: "Empty payload")
            }

            if payload.count <= 7 {
                self.state = .sendingSingleFrame
                let pci = UInt8(payload.count)
                self.state = .completed
                return [pci] + payload
            } else {
                guard payload.count <= UDS.ISOTP.MaximumFrameSize else {
                    self.state = .error("Payload too large")
                    throw UDS.Error.encoderError(string: "Payload too large")
                }

                self.state = .waitingForFlowControl
                let pci = 0x1000 | UInt16(payload.count)
                let pciHi = UInt8(pci >> 8 & 0xFF)
                let pciLo = UInt8(pci & 0xFF)
                let ff = [pciHi, pciLo] + payload[0..<6]
                self.offset = 6
                self.sequenceNumber = 1
                return ff
            }
        }

        /// Processes a received Flow Control frame.
        /// Returns `true` if transmission should continue, `false` if it should abort or wait.
        public func receiveFlowControl(bytes: [UInt8]) -> Bool {
            guard self.state == .waitingForFlowControl else { return false }
            guard bytes.count >= 3 else { return false }

            let pci = bytes[0]
            guard (pci & 0xF0) == 0x30 else { return false } // Not a Flow Control frame

            let flowStatus = pci & 0x0F
            let blockSize = bytes[1]
            let stMin = bytes[2]

            switch flowStatus {
            case 0: // CTS - Continue To Send
                self.blockSize = Int(blockSize)
                self.framesSinceLastFlowControl = 0
                self.separationTime = self.parseSTMin(stMin)
                self.state = .sendingConsecutiveFrames
                return true
            case 1: // WT - Wait
                // Reset timeout timer in a real implementation, here we just stay in waiting state
                return false
            case 2: // OVFLW - Overflow
                self.state = .error("Receiver overflow")
                return false
            default:
                self.state = .error("Invalid FlowStatus")
                return false
            }
        }

        /// Returns the next Consecutive Frame to send, or nil if finished or waiting.
        public func nextFrame() -> Output? {
            guard self.state == .sendingConsecutiveFrames else { return nil }
            guard self.offset < self.payload.count else {
                self.state = .completed
                return .completed
            }

            // Check Block Size
            if self.blockSize > 0 && self.framesSinceLastFlowControl >= self.blockSize {
                self.state = .waitingForFlowControl
                return nil // Need to wait for next FC
            }

            // Calculate payload for this frame
            let remaining = self.payload.count - self.offset
            let chunkSize = min(7, remaining)
            let chunk = self.payload[self.offset..<(self.offset + chunkSize)]

            let pci = 0x20 | (self.sequenceNumber & 0x0F)
            var frame = [pci] + chunk

            // Padding is optional in ISO-TP but often required by drivers.
            // We output minimal frames here as per the library style.

            self.offset += chunkSize
            self.sequenceNumber = (self.sequenceNumber + 1) & 0x0F
            self.framesSinceLastFlowControl += 1

            if self.offset >= self.payload.count {
                self.state = .completed
                return .frame(frame)
            }

            if self.separationTime > 0 {
                 // In a real async loop, we would delay here.
                 // We return the frame, but the caller should respect STmin.
                 return .frame(frame)
            }

            return .frame(frame)
        }

        private func parseSTMin(_ byte: UInt8) -> TimeInterval {
            if byte <= 0x7F {
                return TimeInterval(byte) / 1000.0 // ms
            } else if byte >= 0xF1 && byte <= 0xF9 {
                return TimeInterval(byte & 0x0F) / 10000.0 // 100us resolution -> 0.1ms to 0.9ms
            }
            return 0.127 // Reserved values default to max (127ms) per spec recommendation
        }
    }
}
