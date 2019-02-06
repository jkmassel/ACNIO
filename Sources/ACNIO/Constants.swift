//
//  Constants.swift
//  ACNIO
//
//  Created by Jeremy Massel on 2019-01-13.
//

import Foundation

internal let E131_PREAMBLE_SIZE = 0x0010
internal let E131_POSTABLE_SIZE = 0x0000

internal let E131_ACN_PID: [UInt8] = [ 0x41, 0x53, 0x43, 0x2d, 0x45, 0x31, 0x2e, 0x31, 0x37, 0x00, 0x00, 0x00 ]
internal let E131_STRING = String(bytes: E131_ACN_PID, encoding: .utf8)
public let E131_DEFAULT_PORT: UInt16 = 5568
