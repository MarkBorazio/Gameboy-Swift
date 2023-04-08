//
//  UInt8+Extensions.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 15/8/21.
//

import Foundation

extension UInt8 {
    var lowNibble: UInt8 { self & 0b00001111 }
    var highNibble: UInt8 { (self & 0b11110000) >> 4 }
}
