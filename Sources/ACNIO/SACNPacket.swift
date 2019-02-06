//
//  SACNPacket.swift
//  ACNIO
//
//  Created by Jeremy Massel on 2019-01-12.
//

import Foundation
import NIO

public struct SACNPacket {

    private let byteBuffer: ByteBuffer

    init?(_ data: ByteBuffer) {
        guard SACNPacket.validate(buffer: data) else { return nil }
        self.byteBuffer = data

        guard self.validate() else { return nil }
    }

    init?(_ data: Data) {
        
//        assert(data.count == 638)
        var buffer = ByteBufferAllocator.init().buffer(capacity: data.count)
        buffer.write(bytes: data)

        self.init(buffer)
    }

    private static func validate(buffer: ByteBuffer) -> Bool {

        // Ensure we have the correct number of bytes
        guard buffer.readableBytesView.count == 638 else { return false }

        return true
    }

    private func validate() -> Bool {
        // Check that the packet header is present and correct
        guard self.packetID == E131_STRING else { return false }

        return true
    }

    public var sourceName: String {
        return self.framingLayer
            .getBytes(at: 6, length: 64)!
            .filter{ $0 != 0x0 }
            .stringValue
    }

    public var priority: UInt8 {
        return self.framingLayer
            .getBytes(at: 70, length: 1)!
            .first!
    }

    internal var sequenceNumber: UInt8 {
        return self.framingLayer
            .getBytes(at: 73, length: 1)!
            .first!
    }

    public var universeNumber: DMXUniverseNumber {
        let bytes = self.framingLayer.getBytes(at: 75, length: 2)!
        let highByte = bytes.first!
        let lowByte = bytes.last!

        return DMXUniverseNumber(lowByte: lowByte, highByte: highByte)
    }

    /// ACN Root Layer: 38 bytes
    /// 00 - 01 : Preamble Size [uint16]
    /// 02 - 03 : Postamble Size [uint16]
    /// 04 - 15 : ACN Packet Identifier (max 12 bytes)
    /// 16 - 17 : Flags (high 4 bits) & Length (low 12 bits)
    /// 18 - 21 : Layer Vector [uint32]
    /// 22 - 37 : Component Identifier (UUID – max 16 bytes)
    private var rootLayer: ByteBuffer {
        return self.byteBuffer.getSlice(at: 0, length: 38)!
    }

    internal var packetID: String {
        return self.rootLayer
            .getBytes(at: 4, length: 12)!
            .stringValue
    }

    public var componentIdentifier: String {
        return self.rootLayer
            .getBytes(at: 22, length: 16)!
            .stringValue
    }

    /// Framing Layer: 77 bytes
    /// 00 - 01 : Flags (high 4 bits) & Length (low 12 bits)
    /// 02 - 05 : Layer Vector [uint32]
    /// 06 - 69 : Source Name (max 64 bytes)
    /// 70      : Packet Priority
    /// 71 - 72 : Reserved (should be always 0) [uint16]
    /// 73      : Sequence Number
    /// 74      : Options Flags (bit 7: preview data, bit 6: stream terminated)
    /// 75 - 76 : DMX Universe [uint16]
    private var framingLayer: ByteBuffer {
        return self.byteBuffer.getSlice(at: 38, length: 77)!
    }

    /// Device Management Protocol (DMP) Layer: 523 bytes
    /// 000 - 001 : Flags (high 4 bits) & Length (low 12 bits)
    /// 002       : Layer Vector [uint8]
    /// 003       : Address Type & Data Type [uint8]
    /// 004 - 005 : First Property Address [uint16]
    /// 006 - 007 : Address Increment
    /// 008 - 009 : Property Value Count (1 + number of slots)
    /// 010       : DMX Start Code
    /// 011 - 522 : DMX Universe Data
    private var dmpLayer: ByteBuffer {
        return self.byteBuffer.getSlice(at: 115, length: 523)!
    }

    public var DMXStartCode: UInt8 {
        return self.dmpLayer.getBytes(at: 10, length: 1)!.first!
    }

    public var channels: DMXChannels {
        return DMXChannels(self.dmpLayer.getBytes(at: 11, length: 512)!)
    }
}

public struct DMXChannels {
    internal var channels: [UInt8]

    init(_ channels: [UInt8]) {
        self.channels = channels
    }
}

extension DMXChannels: Collection {

    public func value(forChannel channelNumber: UInt) -> UInt8 {
        guard channelNumber > 0 && channelNumber <= 512 else { return 0 }
        let zeroBasedChannelNumber = channelNumber - 1
        return self.channels[Int(zeroBasedChannelNumber)]
    }

    public var startIndex: UInt {
        return 0
    }

    public var endIndex: UInt {
        return UInt(self.channels.count)
    }

    public func index(after i: UInt) -> UInt {
        let ix = self.channels.index(after: Int(i))
        return UInt(ix)
    }

    public subscript(i: UInt) -> UInt8 {
        guard i >= 0 && i <= 511 else { return 0 }
        return channels[Int(i)]
    }
}

internal extension Array where Element == UInt8 {

    var stringValue: String {
        return String(bytes: self, encoding: .utf8)!
    }
}
