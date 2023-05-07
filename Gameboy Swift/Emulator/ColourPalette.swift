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
    }

    // First bit pair is for colour ID 0
    // Second bit pair is for colour ID 1
    // Third bit pair is for colour ID 2
    // Fourth bit pair is for colour ID 3
    // We can use the value of the colour ID to index each bit pair
    static func getColour(pixelData: PixelData) -> UInt32 {
        
        let debugProperties = GameBoy.instance.debugProperties
        
        let bitShiftLength = pixelData.id * bitsPerColourID
        let rawColour = (pixelData.palette >> bitShiftLength) & bitMask
        switch rawColour {
        case Self.whiteRaw: return debugProperties.colour1 ?? white
        case Self.lightGreyRaw: return debugProperties.colour2 ?? lightGrey
        case Self.darkGreyRaw: return debugProperties.colour3 ?? darkGrey
        case Self.blackRaw: return debugProperties.colour4 ?? black
        default: Coordinator.instance.crash(message: "Invalid colour ID found. Got \(rawColour.hexString()).")
        }
    }
}

// MARK: - Constants

extension ColourPalette {
    private static let bitsPerColourID: UInt8 = 2
    private static let bitMask: UInt8 = 0b11
    
    private static let whiteRaw: UInt8 = 0b00
    private static let lightGreyRaw: UInt8 = 0b01
    private static let darkGreyRaw: UInt8 = 0b10
    private static let blackRaw: UInt8 = 0b11
    
    static let white = UInt32(bytes: [0xFF, 0xFF, 0xFF, 0xFF])!
    static let lightGrey = UInt32(bytes: [0xCC, 0xCC, 0xCC, 0xFF])!
    static let darkGrey = UInt32(bytes: [0x77, 0x77, 0x77, 0xFF])!
    static let black = UInt32(bytes: [0x00, 0x00, 0x00, 0xFF])!
}
