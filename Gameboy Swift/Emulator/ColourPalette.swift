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

    // First bit pair is for colour ID 0
    // Second bit pair is for colour ID 1
    // Third bit pair is for colour ID 2
    // Fourth bit pair is for colour ID 3
    // We can use the value of the colour ID to index each bit pair
    static func getColour(id: UInt8, palette: UInt8) -> NSColor {
        let bitShiftLength = id * bitsPerColourID
        let rawColour = (palette >> bitShiftLength) & bitMask
        switch rawColour {
        case 0b00: return Self.white
        case 0b01: return Self.lightGrey
        case 0b10: return Self.darkGrey
        case 0b11: return Self.black
        default: fatalError()
        }
    }
}

// MARK: - Constants

extension ColourPalette {
    private static let bitsPerColourID: UInt8 = 2
    private static let bitMask: UInt8 = 0b11
}
