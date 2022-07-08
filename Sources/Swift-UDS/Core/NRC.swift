//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
public extension UDS {

    static let NegativeResponse: UInt8 = 0x7F

    /// UDS negative response codes as defined in ISO14229-1:2020
    enum NegativeResponseCode: UInt8 {
        case generalReject                               = 0x10
        case serviceNotSupported                         = 0x11
        case subFunctionNotSupported                     = 0x12
        case incorrectMessageLengthOrInvalidFormat       = 0x13
        case responseTooLong                             = 0x14

        case busyRepeatRequest                           = 0x21
        case conditionsNotCorrect                        = 0x22
        case kwpRoutineNotCompleteOrServiceInProcess     = 0x23
        case requestSequenceError                        = 0x24

        case requestOutOfRange                           = 0x31
        case securityAccessDenied                        = 0x33
        case invalidKey                                  = 0x35
        case exceedNumberOfAttempts                      = 0x36
        case requiredTimeDelayNotExpired                 = 0x37

        case kwpDownloadNotAccepted                      = 0x40
        case kwpImproperDownloadType                     = 0x41
        case kwpCanNotDownloadToSpecifiedAddress         = 0x42
        case kwpCanNotDownloadNumberOfBytesRequested     = 0x43

        case kwpUploadNotAccepted                        = 0x50
        case kwpImproperUploadType                       = 0x51
        case kwpCanNotUploadFromSpecifiedAddress         = 0x52
        case kwpCanNotUploadNumberOfBytesRequested       = 0x53

        case uploadDownloadNotAccepted                   = 0x70
        case transferDataSuspended                       = 0x71
        case generalProgrammingFailure                   = 0x72
        case wrongBlockSequenceCounter                   = 0x73
        case kwpBlockTransferDataChecksumError           = 0x77
        case requestCorrectlyReceivedResponsePending     = 0x78 // NOT an error but an intermediate response
        case subFunctionNotSupportedInActiveSession      = 0x7E
        case serviceNotSupportedInActiveSession          = 0x7F

        case kwpServiceNotSupportedInActiveDiagMode      = 0x80
        case rpmTooHigh                                  = 0x81
        case rpmTooLow                                   = 0x82
        case engineIsRunning                             = 0x83
        case engineIsNotRunning                          = 0x84
        case engineRunTimeTooLow                         = 0x85
        case temperatureTooHigh                          = 0x86
        case temperatureTooLow                           = 0x87
        case vehicleSpeedTooHigh                         = 0x88
        case vehicleSpeedTooLow                          = 0x89
        case throttlePedalTooHigh                        = 0x8A
        case throttlePedalTooLow                         = 0x8B
        case transmissionRangeNotInNeutral               = 0x8C
        case transmissionRangeNotInGear                  = 0x8D
        case brakeSwitchNotClosed                        = 0x8F

        case shifterLeverNotInPark                       = 0x90
        case torqueConverterClutchLocked                 = 0x91
        case voltageTooHigh                              = 0x92
        case voltageTooLow                               = 0x93

        case kwpChecksumError                            = 0xFA
        case kwpEcuErasingFlash                          = 0xFB
        case kwpEcuProgrammingFlash                      = 0xFC
        case kwpErasingError                             = 0xFD
        case kwpProgrammingError                         = 0xFE

        /// fallback, NOT defined anywhere
        case undefined                                   = 0xDE
    }
}
