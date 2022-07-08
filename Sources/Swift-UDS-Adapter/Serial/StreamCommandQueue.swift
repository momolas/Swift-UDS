//
// Swift-UDS. (C) Dr. Michael 'Mickey' Lauer <mickey@vanille-media.de>
//
#if !canImport(ObjectiveC)
import CoreFoundation // only necessary on non-Apple platforms
#endif
import CornucopiaCore
import Foundation

fileprivate let logger = Cornucopia.Core.Logger()

/// The delegate protocol. Used to communicate extraordinary conditions that (might) need special handling.
public protocol _StreamCommandQueueDelegate: AnyObject {

    func streamCommandQueue(_ streamCommandQueue: StreamCommandQueue, inputStreamReady stream: InputStream)
    func streamCommandQueue(_ streamCommandQueue: StreamCommandQueue, outputStreamReady stream: OutputStream)
    func streamCommandQueue(_ streamCommandQueue: StreamCommandQueue, didReceiveUnsolicitedData data: Data)
    func streamCommandQueue(_ streamCommandQueue: StreamCommandQueue, unexpectedEvent event: Stream.Event, on stream: Stream)
}

/// A stream-based serial command queue with an asynchronous (Swift 5.5 and later) interface.
/// Using this class, we spin a long-lived `Thread` that handles all the I/O via a `RunLoop`.
public final class StreamCommandQueue: Thread {

    /// Error conditions while sending and receiving commands over the stream
    public enum Error: Swift.Error {
        case communication      /// A low-level error while opening, sending, receiving, or closing the underlying IOStream
        case timeout            /// The request was not answered within the specified time
        case invalidEncoding    /// The peer returned data with an invalid encoding
        case shutdown           /// The command queue has been instructed to shutdown
    }

    /// The delegate protocol
    public typealias Delegate = _StreamCommandQueueDelegate

    private var loop: RunLoop!
    public let input: InputStream
    private let output: OutputStream
    private let semaphore: DispatchSemaphore = .init(value: 0)
    private var activeCommand: StreamCommand? {
        didSet {
            logger.trace( self.activeCommand != nil ? "active command now \(self.activeCommand!)" : "no active command")
        }
    }
    private let termination: String

    /// The delegate
    public weak var delegate: Delegate?
    
    /// Create using an input stream and an output stream.
    public init(input: InputStream, output: OutputStream, termination: String = "", delegate: Delegate? = nil) {
        self.input = input
        self.output = output
        self.termination = termination
        self.delegate = delegate
        super.init()
        self.name = "dev.cornucopia.Swift-UDS.StreamCommandQueue"
        #if canImport(ObjectiveC)
        self.threadPriority = 0.9 // we need to serve hardware requests
        #endif
        self.start()
        self.semaphore.wait() // block until the dedicated io thread has been started
    }
    
    public override func main() {
        
        self.loop = RunLoop.current
        self.semaphore.signal()
        
        self.input.delegate = self
        self.output.delegate = self
        self.input.schedule(in: self.loop, forMode: .common)
        self.output.schedule(in: self.loop, forMode: .common)
        logger.trace("\(self.name!) entering runloop")
        while !self.isCancelled {
            self.loop.run(until: Date() + 1)
        }
        logger.trace("\(self.name!) exited runloop")
        if let activeCommand = activeCommand {
            activeCommand.resumeContinuation(throwing: .timeout)
            self.activeCommand = nil
        }
        self.input.remove(from: self.loop, forMode: .common)
        self.output.remove(from: self.loop, forMode: .common)
        self.input.delegate = nil
        self.output.delegate = nil
        self.input.close()
        self.output.close()
    }

    /// Sends a string command over the stream and waits for a response.
    public func send(string: String, timeout: TimeInterval) async throws -> String {

        let response: String = try await withCheckedThrowingContinuation { continuation in
            
            self.loop.perform {
                precondition(self.activeCommand == nil, "Tried to send a command while another one has not been answered yet!")
                
                self.activeCommand = StreamCommand(string: string, timeout: timeout, termination: self.termination, continuation: continuation) {
                    self.timeoutActiveCommand()
                }
                self.outputActiveCommand()
            }
            
        }
        return response
    }
    
    /// Cancels the I/O thread and safely shuts down the streams.
    /// **NOTE**: If you don't call this function, the I/O thread in the background will never stop and the instance will leak.
    public func shutdown() {
        self.cancel()
    }
    
    deinit {
        logger.trace("\(self.name!) destroyed")
    }
}

//MARK:- Helpers
private extension StreamCommandQueue {

    func outputActiveCommand() {
        assert(self == Thread.current)

        guard self.input.streamStatus == .open else { return self.input.open() }
        guard self.output.streamStatus == .open else { return self.output.open() }
        guard self.output.hasSpaceAvailable else { return }
        guard let command = self.activeCommand else {
            logger.notice("outputActiveCommand() called without an active command!?")
            return
        }
        guard command.canWrite else {
            logger.trace("command sent, waiting for response...")
            return
        }
        command.write(to: self.output)
    }

    func inputActiveCommand() {
        assert(self == Thread.current)

        guard self.input.streamStatus == .open else { return }
        guard self.input.hasBytesAvailable else { return }
        guard let command = self.activeCommand else {
            var tempBuffer: [UInt8] = .init(repeating: 0, count: 512)
            let read = self.input.read(&tempBuffer, maxLength: tempBuffer.count)
            guard read > 0 else { return }
            logger.info("ignoring \(read) unsolicited bytes")
            self.delegate?.streamCommandQueue(self, didReceiveUnsolicitedData: Data(tempBuffer[0..<read]))
            return
        }
        guard command.canRead else {
            logger.info("command not ready for reading...")
            return
        }
        command.read(from: self.input)
        if command.isCompleted {
            command.resumeContinuation()
            self.activeCommand = nil
        }
    }
    
    func timeoutActiveCommand() {
        assert(self == Thread.current)

        guard let command = self.activeCommand else {
            logger.error("received timeout for non-existing command")
            return
        }
        logger.info("Command '\(command.request)' timed out after \(command.timeout) seconds.")
        command.resumeContinuation(throwing: .timeout)
        self.activeCommand = nil
    }
    
    func handleErrorCondition(stream: Stream, event: Stream.Event) {
        assert(self == Thread.current)

        logger.info("error condition on stream \(stream): \(event)")
        self.input.delegate = nil
        self.output.delegate = nil
        if let command = self.activeCommand {
            command.resumeContinuation(throwing: .communication)
            self.activeCommand = nil
        }
    }
}

extension StreamCommandQueue: StreamDelegate {

    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        assert(self == Thread.current)

        logger.trace("received stream \(aStream), event \(eventCode) in thread \(Thread.current)")

        switch (aStream, eventCode) {

            case (self.input, .openCompleted):
                self.delegate?.streamCommandQueue(self, inputStreamReady: self.input)
                self.outputActiveCommand()

            case (self.output, .openCompleted):
                self.delegate?.streamCommandQueue(self, outputStreamReady: self.output)
                self.outputActiveCommand()

            case (self.output, .hasSpaceAvailable):
                self.outputActiveCommand()

            case (self.input, .hasBytesAvailable):
                self.inputActiveCommand()

            case (_, .endEncountered), (_, .errorOccurred):
                self.handleErrorCondition(stream: aStream, event: eventCode)
                self.delegate?.streamCommandQueue(self, unexpectedEvent: eventCode, on: aStream)

            default:
                logger.trace("unhandled \(aStream): \(eventCode)")
                break
        }
    }
}
