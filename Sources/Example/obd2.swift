import ArgumentParser
import Foundation
import Swift_UDS_Session

var x: Int32? = nil

struct OBD2: ParsableCommand {

    @OptionGroup() var parentOptions: Example.Options

    @Argument(help: "PID to issue")
    var pid: String

    mutating func run() throws {

        let values = pid.CC_hexDecodedUInt8Array
        guard values.count > 1 else { throw ValidationError("PID needs to be a hex value with minimal length 2") }
        let service = values[0]
        let subfunction = values[1]
        let optionRecord = values.count > 2 ? Array(values[2...]) : []

        let url = parentOptions.url
        let pid = self.pid

        Task {
            do {
                let adapter = try await AdapterConnector(url: url).connectedAdapter(via: .auto)
                print("Adapter connected to vehicle. Issuing PID \(pid)...")
                let pipeline = UDS.Pipeline(adapter: adapter)
                let obd2 = UDS.OBD2Session(with: 0x7e0, replyAddress: 0x7e8, via: pipeline)
                let standard: UDS.GenericResponse = try await obd2.request(service: .custom(serviceId: service, subfunction: subfunction, optionRecord: optionRecord))
                print("Adapter responds with \(standard)")
                x = 0
            } catch {
                print("Can't connect to adapter via '\(url)': \(error)")
                x = -1
            }
        }
        while true {
            if let x = x {
                Foundation.exit(x)
            }
            RunLoop.current.run(until: Date() + 0.5)
        }
    }
}
