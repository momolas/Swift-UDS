//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
import CornucopiaCore

extension UDS {

    /// Describes content in memory.
    public enum DataType: String, Codable, Cornucopia.Core.CaseIterableDefaultsLast {
        /// unsigned byte (UInt8)
        case UBYTE
        /// signed byte (Int8)
        case SBYTE
        /// unsigned word (UInt16)
        case UWORD
        /// signed word (Int16)
        case SWORD
        /// unspecified
        case unspecified
        
        public var length: Int {
            switch self {
                case .UBYTE: return 1
                case .SBYTE: return 1
                case .UWORD: return 2
                case .SWORD: return 2
                case .unspecified: return 0
            }
        }
    }
}
