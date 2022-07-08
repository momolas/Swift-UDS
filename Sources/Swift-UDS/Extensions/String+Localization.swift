//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
import CornucopiaCore
import Foundation

extension String {

    #if os(iOS) || os(tvOS) || os(watchOS)
    var uds_localized: String { NSLocalizedString(self, bundle: Bundle.module, comment: "") }
    #else
    var uds_localized: String { NSLocalizedString(self, bundle: Bundle.CC_module("Swift-UDS"), comment: "") }
    #endif
}

extension UDS.KWPECUIdentificationOption {

    public var uds_localized: String { "KWP_ECUID_\(self, radix: .hex, toWidth: 2)".uds_localized }

}
