//
//  DMXUniverseTests.swift
//  ACNIOTests
//
//  Created by Jeremy Massel on 2019-01-12.
//

import XCTest
@testable import ACNIO

class DMXUniverseNumberTests: XCTestCase {

    func testDMXUniverse1() {

        let unv = DMXUniverseNumber(1)

        XCTAssert(unv.highBytes == 0)
        XCTAssert(unv.lowBytes == 1)
        XCTAssert(unv.ipAddress == "239.255.0.1")
    }

    func testDMXUniverse0() {

        let unv = DMXUniverseNumber(0)

        XCTAssert(unv.highBytes == 0)
        XCTAssert(unv.lowBytes == 0)
        XCTAssert(unv.ipAddress == "239.255.0.0")
    }

    func testDMXUniverse255() {
        let unv = DMXUniverseNumber(255)

        XCTAssert(unv.highBytes == 0)
        XCTAssert(unv.lowBytes == 255)
        XCTAssert(unv.ipAddress == "239.255.0.255")
    }

    func testDMXUniverse256() {
        let unv = DMXUniverseNumber(256)

        XCTAssert(unv.highBytes == 1)
        XCTAssert(unv.lowBytes == 0)
        XCTAssert(unv.ipAddress == "239.255.1.0")
    }

    func testDMXUniverseMax() {
        let unv = DMXUniverseNumber(65535)

        XCTAssert(unv.highBytes == 255)
        XCTAssert(unv.lowBytes == 255)
        XCTAssert(unv.ipAddress == "239.255.255.255")
    }

    func testInitDMXUniverse1() {
        let unv = DMXUniverseNumber(lowByte: 1, highByte: 0)
        XCTAssert(unv == 1)
    }

    func testInitDMXUniverse255() {
        let unv = DMXUniverseNumber(lowByte: 255, highByte: 0)
        XCTAssert(unv == 255)
    }

    func testInitDMXUniverse256() {
        let unv = DMXUniverseNumber(lowByte: 0, highByte: 1)
        XCTAssert(unv == 256)
    }

    func testInitDMXUniverseMax() {
        let unv = DMXUniverseNumber(lowByte: 255, highByte: 255)
        XCTAssert(unv == 65535)
    }
}
