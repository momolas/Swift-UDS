import XCTest
@testable import Swift_UDS

final class KWPECUIdentification: XCTestCase {

    func testParseLong() throws {

        let dataTable = "0000316903000320202031393034303932373832373936323738323435305363616E696120435620414232303135313033303135333033303237325953325236583430303035343132373335313932343039313030373237383333313336312E37302E3030454D5320533820204443313331323500002BDC03000320202031393039303632333030343532323535383236392E30303139323430393232323738313634323138353731383058504920363138303832372030393A31383A323120547970653A63742020464C415348205665723A363137303030202032373831363432202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020202020545255434B2F425553444331333132352020496E6420412020434F4D505F533756325F312E32362E30".CC_hexDecodedUInt8Array

        let scalingTable = "03708A037166038767038867038960038A6C038B68038C6904906F6203916703936303946703956804976F6003988A039966039E67039F6A03A06703A16103A26703A56703B16503B26005B46F6F6D08B56F6F6F6F6F6403B66904B76F6104BA6F61FF".CC_hexDecodedUInt8Array

        let ecuIdentifiers = try UDS.KWP.ECUIdentificationEntry.createFrom(dataTable: dataTable, scalingTable: scalingTable)
        XCTAssertEqual(ecuIdentifiers.count, 29)

        /*
         for value in ecuIdentifiers {
         print("\(value.option.uds_localized) = '\(value.data.CC_asciiDecodedString)'")
         }
         */

        let identifierOptions = ecuIdentifiers.map { $0.option }
        XCTAssert(identifierOptions.contains(0x90))

        XCTAssertEqual(ecuIdentifiers.first { $0.option == 0x90 }?.data.CC_asciiDecodedString, "YS2R6X40005412735")

        let asciiIdentifiers = ecuIdentifiers.filter { $0.type == .ascii }
        XCTAssertEqual(asciiIdentifiers.count, 27)
    }

    func testParseShort() throws {

        let dataTable = "5363616E696120435620414232303135313033303135333033303237323139323430393130303753385F424F4F5432303635363735313932343039323231383537313830".CC_hexDecodedUInt8Array

        let scalingTable = "038A6C038B68038C69039167039363039767039E6703A06703A16103A567FF".CC_hexDecodedUInt8Array

        let ecuIdentifiers = try UDS.KWP.ECUIdentificationEntry.createFrom(dataTable: dataTable, scalingTable: scalingTable)
        XCTAssertEqual(ecuIdentifiers.count, 10)

        /*
        for value in ecuIdentifiers {
            print("\(value.option.uds_localized) = '\(value.data.CC_asciiDecodedString)'")
        }
        */

        let identifierOptions = ecuIdentifiers.map { $0.option }
        XCTAssert(identifierOptions.contains(0x9E))

        XCTAssertEqual(ecuIdentifiers.first { $0.option == 0x9E }?.data.CC_asciiDecodedString, "2065675")

        let asciiIdentifiers = ecuIdentifiers.filter { $0.type == .ascii }
        XCTAssertEqual(asciiIdentifiers.count, 10)
    }
}
