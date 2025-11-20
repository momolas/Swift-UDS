//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
import Foundation

public extension UDS {

    enum Renault {

        /// Renault specific services or identifiers could be defined here.
        /// For example, specific Data Identifiers (DIDs) used in ReadDataByIdentifier (0x22).

        public enum DID: DataIdentifier {
            // Example DIDs for Renault (Hypothetical or based on common knowledge)
            // Real DIDs would need to be sourced from a database like PyRen or DDT2000
            case odometer           = 0xF40D // Example: Dashboard Odometer
            case fuelLevel          = 0xF402 // Example: Fuel Level
            case oilTemperature     = 0x2001 // Example
        }

        // Renault often uses Service 0x21 (KWP) for older ECUs, but UDS (0x22) for newer ones.
        // We will ensure Service 0x21 is available in the main Services.swift.
    }
}
