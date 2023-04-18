//
//  File.swift
//  
//
//  Created by Dr. Michael Lauer on 25.01.22.
//
import CornucopiaStreams
import Foundation
import Swift_UDS_Adapter

class AdapterConnector {

    typealias AdapterContinuation = CheckedContinuation<UDS.BaseAdapter, Swift.Error>

    let url: URL
    var adapter: UDS.BaseAdapter?
    var continuation: AdapterContinuation?

    enum Error: Swift.Error {
        case invalidUrl
        case adapterNotFound
        case unsupportedProtocol
    }

    init(url: String) throws {
        guard let url = URL(string: url) else { throw Error.invalidUrl }
        guard let _ = url.scheme else { throw Error.invalidUrl }
        self.url = url

        NotificationCenter.default.addObserver(self, selector: #selector(onAdapterCanInitHardware), name: UDS.AdapterCanInitHardware, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onAdapterDidUpdateState), name: UDS.AdapterDidUpdateState, object: nil)
    }

    deinit {
        print("Destructing \(self)")
    }

    func connectedAdapter(via: UDS.BusProtocol) async throws -> UDS.BaseAdapter {
        let streams = try await Stream.CC_getStreamPair(to: self.url)
        let adapter: UDS.BaseAdapter
        switch self.url.scheme {
            default:
                adapter = UDS.GenericSerialAdapter(inputStream: streams.0, outputStream: streams.1)
        }

        return try await withCheckedThrowingContinuation( { (c: AdapterContinuation) in
            self.continuation = c
            self.adapter = adapter
            adapter.connect(via: .auto)
        })
    }
}

extension AdapterConnector {

    @objc func onAdapterCanInitHardware() {
        // Reset the UART speed (necessary on macOS) after opening the stream
        if url.scheme == "tty" {
            print("fixing up UART")
            let fd = open(url.path, 0)
            var settings = termios()
            cfsetspeed(&settings, speed_t(B115200))
            tcsetattr(fd, TCSANOW, &settings)
            close(fd)
        }
    }

    @objc func onAdapterDidUpdateState(n: Notification) {
        guard let adapter = n.object as? UDS.BaseAdapter, adapter == self.adapter else { return }
        guard let continuation = self.continuation else { return }

        switch adapter.state {
            case .connected(_, _):
                continuation.resume(returning: adapter)
            case .notFound:
                continuation.resume(throwing: Error.adapterNotFound)
            case .unsupportedProtocol:
                continuation.resume(throwing: Error.unsupportedProtocol)
            default:
                print("Adapter state now \(adapter.state)")
        }
    }
}
