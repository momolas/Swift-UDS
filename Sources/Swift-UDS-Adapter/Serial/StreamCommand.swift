//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
#if !canImport(ObjectiveC)
import CoreFoundation // only necessary on non-Apple platforms
#endif
import CornucopiaCore
import Foundation

fileprivate let logger = Cornucopia.Core.Logger()

/// Represents a single command to be sent over the stream
final class StreamCommand {
    
    typealias Continuation = CheckedContinuation<String, Error>
    
    private enum State {
        case created
        case transmitting
        case transmitted
        case responding
        case completed
        case failed
    }
    
    private var outputBuffer: [UInt8] = []
    private var inputBuffer: [UInt8] = []
    private var tempBuffer: [UInt8] = .init(repeating: 0, count: 8192)
    private var state: State = .created
    private let continuation: Continuation
    var timestamp: CFTimeInterval?
    var request: String
    let termination: [UInt8]
    let timeout: TimeInterval
    let timeoutHandler: () -> Void
    weak var timer: Timer?
    
    var canWrite: Bool { self.state == .created || self.state == .transmitting }
    var canRead: Bool { self.state == .transmitted || self.state == .responding }
    var isCompleted: Bool { self.state == .completed }
    
    public init(string: String, timeout: TimeInterval, termination: String, continuation: Continuation, timeoutHandler: @escaping( () -> Void)) {
        self.request = string
        self.outputBuffer = Array(string.utf8)
        self.termination = Array(termination.utf8)
        self.timeout = timeout
        self.timeoutHandler = timeoutHandler
        self.continuation = continuation
    }
    
    func write(to stream: OutputStream) {
        precondition(self.canWrite)
        self.state = .transmitting
        
        let written = stream.write(&outputBuffer, maxLength: outputBuffer.count)
        outputBuffer.removeFirst(written)
        logger.trace("wrote \(written) bytes")
        if outputBuffer.isEmpty {
            self.state = .transmitted
            self.timestamp = CFAbsoluteTimeGetCurrent()
            let timer = Timer.init(fire: Date() + self.timeout, interval: 0, repeats: false) { _ in
                self.timeoutHandler()
            }
            RunLoop.current.add(timer, forMode: .common)
            self.timer = timer
        }
    }
    
    func read(from stream: InputStream) {
        precondition(self.canRead)
        self.state = .responding
        
        let read = stream.read(&self.tempBuffer, maxLength: self.tempBuffer.count)
        logger.trace("read \(read) bytes: \(self.tempBuffer[..<read])")
#if false //!TRUST_ALL_INPUTS
        // Some adapters insert spurious 0 bytes into the stream, hence we need a additional clearance
        self.tempBuffer.forEach {
            if $0.CC_isASCII {
                self.inputBuffer.append($0)
            }
        }
#else
        self.inputBuffer += self.tempBuffer[0..<read]
#endif
        guard let terminationRange = self.inputBuffer.lastRange(of: self.termination) else {
            logger.trace("did not find termination")
            return
        }
        logger.trace("got termination at \(terminationRange)")
        self.timer?.invalidate()
        self.timer = nil
        self.inputBuffer.removeLast(terminationRange.count)
        self.state = .completed
    }
    
    func resumeContinuation(throwing error: StreamCommandQueue.Error? = nil) {
        
        if let error = error {
            self.state = .failed
            self.continuation.resume(throwing: error)
            return
        }
        guard let response = String(bytes: self.inputBuffer, encoding: .utf8) else {
            self.continuation.resume(throwing: StreamCommandQueue.Error.invalidEncoding)
            return
        }
        let duration = String(format: "%04.0f ms", 1000 * (CFAbsoluteTimeGetCurrent() - self.timestamp!))
        logger.debug("Command processed [\(duration)]: '\(self.request.CC_escaped)' => '\(response.CC_escaped)'")
        self.continuation.resume(returning: response)
    }
    
    deinit {
        self.timer?.invalidate()
        self.timer = nil
    }
}

extension StreamCommand: CustomStringConvertible {
    
    var description: String {
        "StreamCommand [\(self.state)]: '\(self.request.CC_escaped)' -> '\(String(decoding: self.inputBuffer, as: UTF8.self).CC_escaped)'"
    }
}
