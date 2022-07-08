//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
import Foundation
@_exported import Swift_UDS

extension UDS {

    /// The adapter information. These are gathered during the adapter initialization phase.
    /// With the original ELM327 (and its various clones) chances are there are no meaningful
    /// information in this structure. Custom adapters, such as the STN-family and the WGsoft.de
    /// ones hand out more information.
    public struct AdapterInfo: Equatable {
        /// The model name.
        public var model: String
        /// The underlying integrated circuit.
        public var ic: String
        /// The vendor name.
        public var vendor: String
        /// The serial number.
        public var serialNumber: String
        /// The firmware version.
        public var firmwareVersion: String

        public init(model: String, ic: String, vendor: String, serialNumber: String, firmwareVersion: String) {
            self.model = model
            self.ic = ic
            self.vendor = vendor
            self.serialNumber = serialNumber
            self.firmwareVersion = firmwareVersion
        }
    }

    /// The adapter state.
    public enum AdapterState: Equatable {
        /// The initial state.
        case created                                        // => searching
        /// Trying to communicate with the adapter.
        case searching                                      // => notFound || initializing
        /// The adapter did not respond.
        case notFound                                       // (terminal)
        /// The adapter is present and initializing.
        case initializing                                   // => error || configuring
        /// The adapter has been recognized and is being prepared for bus connection.
        case configuring(AdapterInfo)                       // => error || connected || unsupportedProtocol
        /// The adapter has successfully connected to the bus via the protocol.
        /// Any messages received by devices connected to the bus during the initialization are recorded.
        case connected(BusProtocol, [UDS.Message])          // => gone
        /// An unsupported bus protocol was detected.
        case unsupportedProtocol                            // => gone
        /// The adapter has (unexpectedly) disconnected.
        case gone                                           // (terminal)
        
        public var isConnected: Bool {
            if case .connected(_, _) = self {
                return true
            } else {
                return false
            }
        }
    }
    
    /// Sent after a change of the adapter state.
    public static let AdapterDidUpdateState: Notification.Name = .init("AdapterDidUpdateState")
    /// Sent after opening the hardware input. May be used for further hardware configuration.
    public static let AdapterCanInitHardware: Notification.Name = .init("AdapterCanInitHardware")
}

/// The adapter API
public protocol _UDSAdapter {

    /// Details about the adapter. Not available in adapter states.
    var info: UDS.AdapterInfo? { get }
    /// The current state of the adapter.
    var state: UDS.AdapterState { get }
    /// The MTU for data transfer. Especially important for firmware upgrade which relies on large (4K) ISO-TP segmented UDS messages.
    var mtu: Int { get }

    /// Start connecting to the bus using the specified `busProtocol` – the progress of this operation is reported via changes in the ``state`` property.
    /// If you're not sure which bus protocol is used, use `.auto` for auto negotiation.
    /// NOTE: This will only work if any of the devices on the bus answers to the standard SAE J1979 OBD2 `0100` broadcast queries.
    func connect(via busProtocol: UDS.BusProtocol)
    /// Start connecting to the bus, trying a subset of protocols, and querying for a specific device using a UDS message to test.
    /// The progress of this operation is reported via changes in the ``state`` property.
    /// NOTE: This is mostly useful for non-OBD2 communication.
    func search(via busProtocols: [UDS.BusProtocol], test: UDS.Message)
    /// Start connecting to the bus, trying a subset of protocols, and querying for one (or more) specific devices using a set of UDS messages to test.
    /// For every protocol, the test messages are sent consecutively. The exit strategy depends on the value of the `testAll` parameter:
    /// - If `false`, the first successful test will stop the search and move the state to ``.connected``.
    /// - If `true`, all tests are carried out before advancing the state to ``.connected``.
    /// The progress of this operation is reported via changes in the ``state`` property.
    func search(via busProtocols: [UDS.BusProtocol], tests: [UDS.Message], testAll: Bool)
    /// Send a message and return the result.
    func sendUDS(_ message: UDS.Message) async throws -> UDS.Message
    /// Safely shutdown the adapter.
    func shutdown()
}

extension UDS { public typealias Adapter = _UDSAdapter }
