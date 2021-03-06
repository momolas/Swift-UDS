# Swift-UDS

Swift-UDS is an implementation of the [Unified Diagnostic Services](https://en.wikipedia.org/wiki/Unified_Diagnostic_Services), written in [Swift](https://www.swift.org).

## Introduction

This library is an effort to implement various diagnostic protocols originating in the automotive space, such as:

* __ISO 14229:2020__ : Road vehicles — Unified diagnostic services (UDS)
* __ISO 15765-2:2016__ : Road vehicles — Diagnostic communication over Controller Area Network (DoCAN)
* __SAE J1979:201408__ : Surface Vehicle Standard – (R) E/E Diagnostic Test Modes (OBD2)
* __ISO 14230:2013__ : Road vehicles – Diagnostic communication over K-Line (DoK-Line)
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

## Software

This package contains three modules, `Swift_UDS`, `Swift_UDS_Adapter`, and `Swift_UDS_Session`:

* `Swift_UDS` contains common UDS and OBD2 definitions, types, and structures,
* `Swift_UDS_Adapter` contains generic support for OBD2 adapters with a reference implementation for serial adapters and a thread-safe `actor` pipeline,
* `Swift_UDS_Session` contains both a UDS and a OBD2 session abstraction for higher level UDS and OBD2 calls.

## Hardware

This library is hardware-agnostic and is supposed to work with all kinds of OBD2 adapters. The reference adapter implementation is for generic serial streaming adapters, such as

* ELM327 (and its various clones), **only for OBD2, the ELM327 is NOT suitable for most of UDS**
* STN11xx-based (e.g., OBDLINK SX),
* STN22xx-based (e.g., OBDLINK MX+, OBDLINK EX, OBDLINK CX),
* WGSoft.de UniCarScan 2100 and later,

Support for direct CAN-adapters on Linux (SocketCAN) and macOS (e.g., the Rusoku TouCAN) is planned.

For the actual communication, I advise to use [CornucopiaStreams](https://github.com/Cornucopia-Swift/CornucopiaStreams), which transforms WiFi, Bluetooth Classic, BTLE, and TTY into a common stream-based interface.

## History

In 2016, I started working on automotive diagnostics. I created the iOS app [OBD2 Expert](https://apps.apple.com/app/obd2-experte/id1142156521), which by now has been downloaded over 500.000 times. I released the underlying framework [LTSupportAutomotive](https://github.com/mickeyl/LTSupportAutomotive), written in Objective-C, as open source.

In 2021, I revisited this domain and attempted to implement the UDS protocol on top of the existing library.
Pretty soon though it became obvious that there are [too many OBD2-isms](https://github.com/mickeyl/LTSupportAutomotive/issues/35#issuecomment-808062461) in `LTSupportAutomotive` and extending it with UDS would be overcomplicated and potentially destabilize the library.
Together with [my new focus on Swift](https://www.vanille.de/blog/2020-programming-languages/), I decided to start from scratch with [CornucopiaUDS](https://github.com/Cornucopia-Swift/CornucopiaUDS).

By August 2021, the first working version of `CornucopiaUDS` was working and used in the automotive tuning app [TPE-Tuning](https://apps.apple.com/app/tpe-tuning/id1561470949).
From the start though, the plan has been to make this a "transitioning" library, in particular because of the forthcoming
concurrency features debuting in Swift 5.5: Communication with external hardware is asynchronous by nature, so `async`/`await`
and the `actor` abstractions seemed to be a natural fit.

This library is supposed to become the successor of both `LTSupportAutomotive` and `CornucopiaUDS`. Due to Swift 5.5, on Apple
platforms it comes with a relatively high deployment target – limiting you to iOS 15, tvOS 15, watchOS 8, and macOS 12 (and above).

## Status

Actively maintained and working on Linux and Apple platforms.

### Bus Protocols

Although I have successfully used this library as the base for an ECU reprogramming app, it has _not_ yet been battle-tested. Moreoever, while it has been designed
with all kind of bus protocols in mind, support for CAN is most advanced. Older bus protocols, such as K-LINE, J1850, and ISO9141-2 should be working at least with OBD2,
but your mileage might vary.

### UDS

UDS is about 50% done – I have started with the necessary calls to upload (TESTER -> ECU) new flash firmwares. The other way is not done yet.
There is limited support for the diagnostic commands from KWP and GMLAN and I'm not against adding more, but it's not a personal preference.

### KWP2000 / GMLAN

The KWP2000 session code started out as a copy of the UDS and I'm going to make adjustments as necessary. There are subtle, but important differences in a handful of commands.

### OBD2

Although I plan to implement the full set of OBD2 calls, the primary focus has been on UDS. I have started with a bunch of OBD2 calls to lay out the path for contributors, but did not have time yet to do more. You might want to have a look at the [messageSpecs](https://github.com/Automotive-Swift/Swift-UDS/blob/e2bfbd64dfaefe98375952972f338f1c0089389e/Sources/Swift-UDS/OBD2/OBD2.swift#L102), if you want to help.
Note that this might be an appropriate case for a [`@ResultBuilder`](https://github.com/apple/swift-evolution/blob/main/proposals/0289-result-builders.md).

## Technical Notes

### Request/Response(s) with multiple devices

Although OBD2 (adapters) in general allows dealing with multiple responses for a single request, this library's concept of a diagnostic session is based on a 1:1 relationship.
All diagnostic sessions based on a `Pipeline` are handling this automatically, though if you are using one of the `Adapter` classes directly,
make sure that you have configured the request and response headers accordingly, else you might pick up the answer of more than just one device,
which confuses the internal protocol decoders and hell breaks loose.

Moreover, since https://github.com/Automotive-Swift/Swift-UDS/commit/32d956f58294070fb66a9289ae3ced149558fe31, we optimize the flow of communication
by telling the serial adapter that we only care about exactly one ECU answer, hence we will not pick up anything more. If you are interested in all answers,
you need to query the actual ECUs on the bus (e.g. by inspecting the adapter's `detectedDevices`) and gather the values individually.
It is no problem to have several instances of `OBD2DiagnosticSession` reusing the same `Pipeline`.

While this may sound a bit cumbersome at first, it's the only correct approach for a library optimized for UDS. Yes, we can _also_ do OBD2,
but it's definitely not the focus.

### Requesting multiple OBD2 PIDs at once

The ELM327 (and all its clones and derivatives) have a mode where you can request multiple PIDs in one go (e.g. by sending `01 0c 0d` to get
both the engine and the vehicle speed). In that case, adapter issues every single of those PIDs one by one, collects the responses, and concatenates them.
This saves a tiny amount of bits between the adapter and the controlling machine and was a welcome addition in former times. These days
though, it's more of a nuisance for the parser, and it only works for the SID `0x01` (current frame) anyways. We do not support that in this library.

## Contributions

Feel free to use this under the obligations of the MIT. I welcome all forms of contributions. Stay safe and sound!

# Swift-UDS
