//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
import Foundation

public extension UDS {

    enum KWP {
        public static var HeaderLength: Int = 3 // "87F110" bytes
    }
}

public extension UDS.KWP {

    /// A KWPISOTP encoder, see ISO14230-4
    final class Encoder: UDS.BusProtocolEncoder {

        public init() { }

        /// Encode a byte stream by inserting the appropriate framing control bytes as per ISOTP
        public func encode(_ bytes: [UInt8]) throws -> [UInt8] {
            return try UDS.ISOTP.Encoder().encode(bytes)
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
            let checksum = chunk[7]
            let computedChecksum = chunk.dropLast().reduce(0, &+)
            guard checksum == computedChecksum else {
                throw UDS.Error.decoderError(string: "Checksum error in chunk \(chunk, radix: .hex, prefix: true, toWidth: 2). Expected \(computedChecksum, radix: .hex), got \(checksum, radix: .hex)")
            }

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
