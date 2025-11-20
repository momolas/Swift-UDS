# Swift-UDS

Swift-UDS is an implementation of the [Unified Diagnostic Services](https://en.wikipedia.org/wiki/Unified_Diagnostic_Services), written in [Swift](https://www.swift.org).

## Introduction

This library is an effort to implement various diagnostic protocols originating in the automotive space, such as:

* __ISO 14229:2020__ : Road vehicles — Unified diagnostic services (UDS)
* __ISO 15765-2:2016__ : Road vehicles — Diagnostic communication over Controller Area Network (DoCAN)
* __SAE J1979:201408__ : Surface Vehicle Standard – (R) E/E Diagnostic Test Modes (OBD2)
* __GMW 3110:2010__ : General Motors Local Area Network Enhanced Diagnostic Test Mode Specification (GMLAN)

## Integration

This is an SPM-compatible package for the use with Xcode (on macOS) or other SPM-compliant consumer (wherever Swift runs on).
First, add the package to your package dependencies:
```swift
.package(url: "https://github.com/Automotive-Swift/Swift-UDS", branch: "master")
```

Then, add the library to your target dependencies:
```swift
dependencies: ["Swift-UDS"]
```

## How to Use

First, make sure you are in an `async`hronous context. Then, get a pair of streams to/from your OBD2 adapter. Assuming you are using [CornucopiaStreams](https://github.com/Cornucopia-Swift/CornucopiaStreams), this is as simple as:

```swift
let streams = try await Stream.CC_getStreamPair(to: url, timeout: 3)
```

Once you have the streams, create an `Adapter`:

```swift
let adapter = UDS.GenericSerialAdapter(inputStream: streams.0, outputStream: streams.1)
```

Make sure you observe its state notifications:

```swift
NotificationCenter.default.addObserver(forName: UDS.AdapterDidUpdateState, object: nil, queue: nil) { _ in
   ...
}
```

Then, start connecting to the bus:

```swift
adapter.connect(via: .auto)
```

When the adapter's state changes to `.connected(busProtocol: BusProtocol)` you can observe the negotiated protocol:

```swift
guard case let .connected(busProtocol) = adapter.state else { return }
print("Connected to the bus w/ protocol: \(busProtocol)")
```

While you could already communicate on a low level with the adapter now, it is recommended
that you install a thread-safe `Pipeline` first:

```swift
let pipeline = UDS.Pipeline(adapter: adapter)
```

The final step is creating a session. There are sessions for OBD2 communication and for UDS communication. For this example, let's create the former:

```swift
let session = UDS.OBD2Session(via: pipeline)
```

And this is how we would read the vehicle identification number (VIN) of your connected vehicle:

```swift
do {
    let vin = try await session.readString(service: .vehicleInformation(pid: UDS.VehicleInformationType.vin))
    print("VIN: \(vin)"
} catch {
    print("Could not read the VIN: \(error)")
}
```

## Motivation

In 2016, I started working on automotive diagnostics. I created the iOS app [OBD2 Expert](https://apps.apple.com/app/obd2-experte/id1142156521), which by now has been downloaded over 500.000 times. I released the underlying framework [LTSupportAutomotive](https://github.com/mickeyl/LTSupportAutomotive), written in Objective-C, as open source.

In 2021, I revisited this domain and attmpted to implement the UDS protocol on top of the existing library.
Pretty soon though it became obvious that there are [too many OBD2-isms](https://github.com/mickeyl/LTSupportAutomotive/issues/35#issuecomment-808062461) in `LTSupportAutomotive` and extending it with UDS would be overcomplicated.
Together with [my new focus on Swift](https://www.vanille.de/blog/2020-programming-languages/), I decided to start from scratch with the library [CornucopiaUDS](https://github.com/Cornucopia-Swift/CornucopiaUDS).

By August 2021, the first working version of `CornucopiaUDS` was working and used in the automotive tuning app [TPE-Tuning](https://apps.apple.com/app/tpe-tuning/id1561470949).
From the start though, the plan has been to make this a "transitioning" library, in particular because of the forthcoming
concurrency features debuting in Swift 5.5: Communication with external hardware is asynchronous by nature, so `async`/`await`
and the `actor` abstractions is a natural fit.

This library is supposed to become the successor of both `LTSupportAutomotive` and `CornucopiaUDS`. Due to Swift 5.5, on Apple
platforms it comes with a relatively high deployment target – limiting you to iOS 15, tvOS 15, watchOS 8, and macOS 12 (and above).

## Software

This package contains three modules, `Swift_UDS`, `Swift_UDS_Adapter`, and `Swift_UDS_Session`:

* `Swift_UDS` contains common UDS and OBD2 definitions, types, and structures,
* `Swift_UDS_Adapter` contains generic support for OBD2 adapters with a reference implementation for serial adapters and a thread-safe `actor` pipeline,
* `Swift_UDS_Session` contains both a UDS and a OBD2 session abstraction for higher level UDS and OBD2 calls.

## Hardware

This library is hardware-agnostic and is supposed to work with all kinds of OBD2 adapters. The reference adapter implementation is for generic serial streaming adapters, such as

* ELM327 (and its various clones), **only for OBD2, the ELM327 is NOT suitable for UDS**
* STN11xx-based (e.g., OBDLINK SX),
* STN22xx-based (e.g., OBDLINK MX+, OBDLINK EX, OBDLINK CX),
* WGSoft.de UniCarScan 2100 and later,

Support for direct CAN-adapters (such as the Rusoku TouCAN) is also on the way.

For the actual communication, I advise to use [CornucopiaStreams](https://github.com/Cornucopia-Swift/CornucopiaStreams), which transforms WiFi, Bluetooth Classic, BTLE, and TTY into a common stream-based interface.

## Status

Currently: **Feature-wise on par with CornucopiaUDS, but hardly tested yet**

- October 2021: Public version available. Should be on-par with CornucopiaUDS, but did not receive any substantial testing.
- October 2021: Some concurrency issues have been solved in the meantime, hence starting to (re)implement the first bunch of classes.
- September 2021: Hitting real hard blocks with the state of `async`/`await` in the yet-to-be-released Swift 5.5.
- August 2021: Nothing there yet, I'm still planning.

### Bus Protocols

Although I have successfully used this library as the base for an ECU reprogramming app, it has _not_ yet been battle-tested. Moreoever, while it has been designed
with all kind of bus protocols in mind, support for CAN is most advanced. Older bus protocols, such as K-LINE, J1850, and ISO9141-2 should be working at least with OBD2,
but your mileage might vary.

### UDS

UDS implementation now covers all standard services defined in ISO 14229-1, including:
*   Diagnostic Session Control (0x10)
*   ECU Reset (0x11)
*   Read/Write Data By Identifier (0x22, 0x2E)
*   Read/Write Memory By Address (0x23, 0x3D)
*   Input/Output Control By Identifier (0x2F)
*   Routine Control (0x31)
*   Request Download/Upload (0x34, 0x35) and Transfer Data (0x36)
*   ...and more.

The `AddressAndLengthFormatIdentifier` (ALFID) logic for memory services has been verified against the standard.

### OBD2

The library supports all 10 standard OBD2 modes ($01-$0A). The Fuel Type PID (0x51) and other common PIDs are implemented. The structure is extensible for adding more PIDs.

### Extensions

The library supports manufacturer-specific extensions.
*   **Renault**: Includes support for `ReadDataByLocalIdentifier` (Service 0x21) and Renault-specific DIDs.

## Contributions

Feel free to use this under the obligations of the MIT. I welcome all forms of contributions. Stay safe and sound!

