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
        
        lazy var colourId: UInt8 = {
            let bitShiftLength = id * bitsPerColourID
            return (palette >> bitShiftLength) & bitMask
        }()
        
        var debug = false
    }

    // First bit pair is for colour ID 0
    // Second bit pair is for colour ID 1
    // Third bit pair is for colour ID 2
    // Fourth bit pair is for colour ID 3
    // We can use the value of the colour ID to index each bit pair
    static func getColour(pixelData: PixelData) -> UInt32 {
        if pixelData.debug {
            return UInt32(bytes: [0xA0, 0xB0, 0xC0, 0x0B])!
        }
        
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
    
    private static let white = UInt32(bytes: [0xFF, 0xFF, 0xFF, 0xFF])!
    private static let lightGrey = UInt32(bytes: [0xCC, 0xCC, 0xCC, 0xFF])!
    private static let darkGrey = UInt32(bytes: [0x77, 0x77, 0x77, 0xFF])!
    private static let black = UInt32(bytes: [0x00, 0x00, 0x00, 0xFF])!
}
