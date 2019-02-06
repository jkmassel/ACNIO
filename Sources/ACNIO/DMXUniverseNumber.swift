//
//  DMXUniverse.swift
//  ACNIO
//
//  Created by Jeremy Massel on 2019-01-12.
//

import Foundation

public typealias DMXUniverseNumber = UInt16

extension DMXUniverseNumber {

    init(lowByte: UInt8, highByte: UInt8) {
        self = (UInt16(highByte) << 8) + UInt16(lowByte)
    }

    @inlinable var highBytes: UInt8 {
        return UInt8(self >> 8)
    }

    @inlinable var lowBytes: UInt8 {
        return UInt8(self & 0x00ff)
    }

    @inlinable var ipAddress: String {
        return "239.255.\(highBytes).\(lowBytes)"
    }
}
