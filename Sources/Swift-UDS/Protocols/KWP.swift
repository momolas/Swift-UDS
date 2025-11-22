//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
import Foundation

public extension UDS {

    enum KWP {
        public static var HeaderLength: Int = "87F110".count
    }
}

public extension UDS.KWP {

    /// A KWPISOTP encoder, see ISO14230-4
    final class Encoder: UDS.BusProtocolEncoder {

        public init() { }

        /// Encode a byte stream by inserting the appropriate framing control bytes as per ISOTP
        public func encode(_ bytes: [UInt8]) throws -> [UInt8] {
            guard bytes.count > 0 else { throw UDS.Error.encoderError(string: "Message too small (0 bytes)") }
            guard bytes.count < UDS.ISOTP.MaximumFrameSize else { throw UDS.Error.encoderError(string: "Message too long. Maximum ISOTP payload is 4095 (0xFFF) bytes") }

            let framedPayload = bytes.count <= 7 ? self.encodeSingleFrame(payload: bytes) : self.encodeMultiFrame(payload: bytes)
            return framedPayload
        }

        // encodes bytes to a single frame
        private func encodeSingleFrame(payload: [UInt8]) -> [UInt8] {
            let pci = UInt8(payload.count)
            return [pci] + payload
        }

        // encodes bytes to multiple frames
        private func encodeMultiFrame(payload: [UInt8]) -> [UInt8] {
            var payload = payload
            let pci = 0x1000 | UInt16(payload.count)
            let pciHi = UInt8(pci >> 8 & 0xFF)
            let pciLo = UInt8(pci & 0xFF)
            let ff = [pciHi, pciLo] + payload[0..<6]
            payload.removeFirst(6)
            var bytes = ff
            var cfPci = UInt8(0x21)
            while payload.count > 0 {
                let cfPayloadCount = min(7, payload.count)
                let cf = [cfPci] + payload[0..<cfPayloadCount]
                payload.removeFirst(cfPayloadCount)
                bytes += cf
                cfPci = cfPci + 1
                if cfPci == 0x30 {
                    cfPci = 0x20
                }
            }
            return bytes
        }
    }

    /// A KWP decoder, see ISO14230-4
    final class Decoder: UDS.BusProtocolDecoder {

        public init() { }

        /// Decode a byte stream consisting on multiple individual concatenated frames by removing the protocol framing bytes as per KWP
        public func decode(_ bytes: [UInt8]) throws -> [UInt8] {

            // KWP actually indicates whether we have a single or multi-frame response. That said, just checking the length will do :-)
            guard bytes.count > 9 else { return bytes.dropLast() }
            return try decodeMultiFrame(payload: bytes)
        }
    }
}

private extension UDS.KWP.Decoder {
    
    func decodeMultiFrame(payload bytes: [UInt8]) throws -> [UInt8] {
        
        var result: [UInt8] = []
        var expectedFrame = 1
        
        for chunk in bytes.CC_chunked(size: 8) {
            let frame = chunk[2]
            //FIXME: Should we check the checksum and filter invalid frames?
            //let checksum = chunk[7]
            guard frame == expectedFrame else {
                throw UDS.Error.decoderError(string: "Expected frame \(expectedFrame), but got \(frame) in chunk \(chunk, radix: .hex, prefix: true, toWidth: 2)")
            }
            if frame == 1 {
                result.append(chunk[0])
                result.append(chunk[1])
            }
            result += chunk[3..<7]
            expectedFrame += 1
        }
        return result
    }
}
