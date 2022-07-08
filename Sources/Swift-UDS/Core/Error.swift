//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
public extension UDS {
    
    /// Higher level errors, NOT defined in ISO14229-1
    enum Error: Swift.Error, Equatable {

        /// A non-UDS error occured in the physical layer, e.g., when a serial adapter encounters a 'BUS ERROR'.
        case busError(string: String)
        /// ISOTP encoding did fail.
        case encoderError(string: String)
        /// ISOTP decoding did fail.
        case decoderError(string: String)
        /// The adapter was disconnected.
        case disconnected
        /// An internal problem occured.
        case `internal`(string: String)
        /// A non-UDS error occured during low level transportation, e.g., when a serial adapter encounters a non-ASCII character.
        case invalidCharacters
        /// A UDS (or KWP) format invariant was violated, e.g., when decoding the KWP ECU Identification slices.
        case invalidFormat(string: String)
        /// A ``UDS.Service`` could not be encoded into a ``UDS.Message``. This is a local error.
        case malformedService
        /// A non-UDS error. During adapter communication the response was empty.
        case noResponse
        /// A non-UDS error. During adapter communication a timeout occured.
        case timeout
        /// The UDS command did fail and a negative response code was transmitted.
        case udsNegativeResponse(code: UDS.NegativeResponseCode)
        /// A non-UDS error. There was a mismatch between the expected and the actual data format returned.
        case unexpectedResult(string: String)
        /// The underlying adapter was unsuitable for transmitting a service.
        case unsuitableAdapter
        /// A non-UDS error. During adapter communication the command was not understood.
        case unrecognizedCommand
        /// A non-UDS "error". Everything was good.
        case ok
    }    
}

