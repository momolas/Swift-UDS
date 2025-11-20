import SwiftUI
import Swift_UDS
import Swift_UDS_Adapter
import Swift_UDS_Session
import CornucopiaStreams

class FuzzerViewModel: ObservableObject {
    @Published var connectionUrl: String = "tty:///dev/cu.usbserial-110"
    @Published var isConnected: Bool = false
    @Published var logMessages: [String] = []
    @Published var isFuzzing: Bool = false
    @Published var currentFuzzId: String = "-"

    private var adapter: UDS.Adapter?
    private var pipeline: UDS.Pipeline?
    private var session: UDS.DiagnosticSession?
    private var fuzzTask: Task<Void, Never>?

    // Configuration
    @Published var startId: Int = 0
    @Published var endId: Int = 255
    @Published var serviceIdToFuzz: Int = 0x22 // ReadDataByIdentifier default

    func connect() {
        guard let url = URL(string: connectionUrl) else {
            log("Invalid URL")
            return
        }

        log("Connecting to \(url)...")

        Task {
            do {
                let streams = try await Stream.CC_getStreamPair(to: url, timeout: 3)
                let adapter = UDS.GenericSerialAdapter(inputStream: streams.0, outputStream: streams.1)
                self.adapter = adapter

                // Ideally we should observe state changes here
                // For simplicity in this example, we assume connection proceeds
                adapter.connect(via: .auto)

                // Wait a bit for connection (in a real app, observe state)
                try await Task.sleep(nanoseconds: 2 * 1_000_000_000)

                let pipeline = UDS.Pipeline(adapter: adapter)
                self.pipeline = pipeline
                // Default address 0x7E0 (Engine), Reply 0x7E8
                self.session = UDS.DiagnosticSession(with: 0x7E0, replyAddress: 0x7E8, via: pipeline)

                await MainActor.run {
                    self.isConnected = true
                    self.log("Connected (Assumed)")
                }
            } catch {
                await MainActor.run {
                    self.log("Connection failed: \(error)")
                }
            }
        }
    }

    func startFuzzing() {
        guard let session = session else { return }
        isFuzzing = true

        fuzzTask = Task {
            let range = startId...endId
            log("Starting fuzzing Service 0x\(String(format:"%02X", serviceIdToFuzz)) from \(String(format:"%04X", startId)) to \(String(format:"%04X", endId))")

            for id in range {
                if Task.isCancelled { break }

                let hexId = String(format:"%04X", id)
                await MainActor.run { self.currentFuzzId = hexId }

                do {
                    // Construct payload manually or via Service enum
                    // This is a simplistic fuzzer that assumes 0x22 (ReadDataByIdentifier) for DIDs (2 bytes)
                    // Or 0x01 (CurrentData) for PIDs (1 byte)

                    if serviceIdToFuzz == 0x22 { // ReadDataByIdentifier
                        let did = UInt16(id)
                        // We use the new UDS library call
                        let response = try await session.readDataByIdentifier(id: did)
                        log("[FOUND] DID 0x\(hexId): \(response)")
                    } else if serviceIdToFuzz == 0x01 { // OBD2 Current Data
                         // Not directly supported by UDS.DiagnosticSession helper typically, need manual message or OBD2Session
                         // Let's try generic message send if we want to be generic, but UDS.DiagnosticSession has helpers.
                         // Using OBD2Session for 0x01
                         log("Service 0x01 not fully implemented in generic fuzzer loop yet")
                         break
                    } else {
                        // Generic fuzzing: Try to send a raw message
                        // Message: [ServiceId, IdHigh, IdLow] (assuming 2 byte ID)
                        let idHi = UInt8((id >> 8) & 0xFF)
                        let idLo = UInt8(id & 0xFF)
                        let message = UDS.Message(id: 0x7E0, reply: 0x7E8, bytes: [UInt8(serviceIdToFuzz), idHi, idLo])
                        let response = try await session.send(message)
                        log("[RESPONSE] ID 0x\(hexId): \(response.bytes.map({ String(format: "%02X", $0) }).joined(separator: " "))")
                    }

                } catch {
                    // Log errors only if they are NOT "Service Not Supported" or "Request Out Of Range" to reduce noise?
                    // For fuzzing, we often want to see success.
                    // log("[FAIL] ID 0x\(hexId): \(error)")
                }

                // Rate limit
                try? await Task.sleep(nanoseconds: 50 * 1_000_000) // 50ms
            }

            await MainActor.run {
                self.isFuzzing = false
                self.log("Fuzzing complete")
            }
        }
    }

    func stopFuzzing() {
        fuzzTask?.cancel()
        isFuzzing = false
        log("Fuzzing stopped")
    }

    func log(_ message: String) {
        logMessages.insert(message, at: 0)
        if logMessages.count > 100 { logMessages.removeLast() }
    }
}

struct ContentView: View {
    @StateObject var viewModel = FuzzerViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("UDS Fuzzer")
                .font(.title)

            // Connection Section
            HStack {
                TextField("Connection URL", text: $viewModel.connectionUrl)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Button(viewModel.isConnected ? "Connected" : "Connect") {
                    viewModel.connect()
                }
                .disabled(viewModel.isConnected)
            }
            .padding()

            // Fuzzing Configuration
            GroupBox(label: Text("Configuration")) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Service ID (Hex)")
                        TextField("22", value: $viewModel.serviceIdToFuzz, format: .number)
                    }
                    VStack(alignment: .leading) {
                        Text("Start ID (Int)")
                        TextField("0", value: $viewModel.startId, format: .number)
                    }
                    VStack(alignment: .leading) {
                        Text("End ID (Int)")
                        TextField("255", value: $viewModel.endId, format: .number)
                    }
                }
                .padding()
            }
            .padding(.horizontal)

            // Fuzzing Controls
            HStack {
                Text("Current ID: \(viewModel.currentFuzzId)")
                    .font(.headline)
                    .frame(width: 150, alignment: .leading)

                if viewModel.isFuzzing {
                    Button("Stop") {
                        viewModel.stopFuzzing()
                    }
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                } else {
                    Button("Start Fuzzing") {
                        viewModel.startFuzzing()
                    }
                    .padding()
                    .background(viewModel.isConnected ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .disabled(!viewModel.isConnected)
                }
            }

            // Logs
            List {
                ForEach(viewModel.logMessages, id: \.self) { msg in
                    Text(msg)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(msg.contains("[FOUND]") ? .green : .primary)
                }
            }
            .frame(minHeight: 200)
            .border(Color.gray.opacity(0.5))
            .padding()
        }
        .padding()
    }
}
