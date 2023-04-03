//
//  ColourPalette.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 5/9/21.
//

import Cocoa

struct ColourPalette {
    
    struct PixelData {
        let id: UInt8
        let palette: UInt8
        
        var colourId: UInt8 {
            let bitShiftLength = id * bitsPerColourID
            return (palette >> bitShiftLength) & bitMask
        }
    }

    // First bit pair is for colour ID 0
    // Second bit pair is for colour ID 1
    // Third bit pair is for colour ID 2
    // Fourth bit pair is for colour ID 3
    // We can use the value of the colour ID to index each bit pair
    static func getColour(pixelData: PixelData) -> NSColor {
        let bitShiftLength = pixelData.id * bitsPerColourID
        let rawColour = (pixelData.palette >> bitShiftLength) & bitMask
        switch rawColour {
        case 0b00: return white
        case 0b01: return lightGrey
        case 0b10: return darkGrey
        case 0b11: return black
        default: fatalError()
        }
    }
}

// MARK: - Constants

extension ColourPalette {
    private static let bitsPerColourID: UInt8 = 2
    private static let bitMask: UInt8 = 0b11
    
    static let whiteColourId: UInt8 = 0b00
    static let lightGreyColourId: UInt8 = 0b01
    static let darkGreyColourId: UInt8 = 0b10
    static let blackColourId: UInt8 = 0b11
    
    private static let white = NSColor.white
    private static let lightGrey = NSColor(red: 0xCC, green: 0xCC, blue: 0xCC, alpha: 1)
    private static let darkGrey = NSColor(red: 0x77, green: 0x77, blue: 0x77, alpha: 1)
    private static let black = NSColor.black
}
