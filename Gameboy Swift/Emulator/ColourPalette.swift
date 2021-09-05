//
//  ColourPalette.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 5/9/21.
//

import Cocoa

struct ColourPalette {
    static let white = NSColor.white
    static let lightGrey = NSColor(red: 0xCC, green: 0xCC, blue: 0xCC, alpha: 1)
    static let darkGrey = NSColor(red: 0x77, green: 0x77, blue: 0x77, alpha: 1)
    static let black = NSColor.black

    // First bit pair is for colour ID 00
    // Second bit pair is for colour ID 01
    // Third bit pair is for colour ID 10
    // Fourth bit pair is for colour ID 11
    // We can use the colour ID to index each bit pair
    static func getColour(id: Int, byte: UInt8) -> NSColor {
        let bitShiftLength = id * bitsPerColourID
        let rawColour = (byte >> bitShiftLength) & bitMask
        switch rawColour {
        case 0b00: return Self.white
        case 0b01: return Self.lightGrey
        case 0b10: return Self.darkGrey
        case 0b11: return Self.black
        default: fatalError()
        }
    }
}

// MARK - Constants

extension ColourPalette {
    
    private static let bitsPerColourID = 2
    private static let bitMask: UInt8 = 0b11
}
