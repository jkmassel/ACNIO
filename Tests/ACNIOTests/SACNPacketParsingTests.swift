//
//  SACNPacketParsingTests.swift
//  ACNIOTests
//
//  Created by Jeremy Massel on 2019-01-13.
//

import XCTest
@testable import ACNIO

class SACNPacketParsingTests: XCTestCase {

    private var allOnPacket = SACNPacket(Data(bytes: AllOn))!

    func testAllOnAccessors() {

        XCTAssertEqual(allOnPacket.sourceName, "sACNView")
        XCTAssertEqual(allOnPacket.packetID.data(using: .utf8), Data(E131_ACN_PID))
        XCTAssertEqual(allOnPacket.universeNumber, 32)
        XCTAssertEqual(allOnPacket.sequenceNumber, 39)
        XCTAssertEqual(allOnPacket.priority, 100)
        XCTAssertEqual(allOnPacket.DMXStartCode, 0)
        XCTAssertEqual(allOnPacket.componentIdentifier, "{45aca856-5f92-4")

        allOnPacket.channels.enumerated().forEach { ix, value in
            XCTAssertEqual(value, 255, "Channel \(ix) should be 255")
        }

        XCTAssertEqual(allOnPacket.channels[0], 255, "Channel 0 should be 255")
        XCTAssertEqual(allOnPacket.channels[511], 255, "Channel 255 should be 255")
        XCTAssertEqual(allOnPacket.channels[512], 0, "Channel 256 should be 0 when checked from subscript")

        XCTAssertEqual(allOnPacket.channels.value(forChannel: 0), 0, "Channel 0 should be 0")
        XCTAssertEqual(allOnPacket.channels.value(forChannel: 1), 255, "Channel 1 should be 255")
        XCTAssertEqual(allOnPacket.channels.value(forChannel: 512), 255, "Channel 512 should be 255")
        XCTAssertEqual(allOnPacket.channels.value(forChannel: 513), 0, "Channel 513 should be 0")
    }
}
