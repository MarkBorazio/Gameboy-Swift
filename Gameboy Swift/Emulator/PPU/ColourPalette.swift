//
//  ColourPalette.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 5/9/21.
//

import Cocoa

struct ColourPalette: Equatable {
    var colour0: UInt32
    var colour1: UInt32
    var colour2: UInt32
    var colour3: UInt32
    
    func getColour(pixelData: PixelData) -> UInt32 {
        
        let bitShiftLength = pixelData.id * Self.bitsPerColourID
        let rawColour = (pixelData.palette >> bitShiftLength) & Self.bitMask
        
        switch rawColour {
        case Self.colourId1: return colour0
        case Self.colourId2: return colour1
        case Self.colourId3: return colour2
        case Self.colourId4: return colour3
        default: Coordinator.instance.crash(message: "Invalid colour ID found. Got \(rawColour.hexString()).")
        }
    }
}

// MARK: - Instances

extension ColourPalette {
    
    static let blackAndWhite = ColourPalette(
        colour0: UInt32(bytes: [0xFF, 0xFF, 0xFF, 0xFF])!,
        colour1: UInt32(bytes: [0xCC, 0xCC, 0xCC, 0xFF])!,
        colour2: UInt32(bytes: [0x77, 0x77, 0x77, 0xFF])!,
        colour3: UInt32(bytes: [0x00, 0x00, 0x00, 0xFF])!
    )
    
    static let dmg = ColourPalette(
        colour0: UInt32(bytes: [0x9B, 0xBC, 0x0F, 0xFF])!,
        colour1: UInt32(bytes: [0x8B, 0xAC, 0x0F, 0xFF])!,
        colour2: UInt32(bytes: [0x30, 0x62, 0x30, 0xFF])!,
        colour3: UInt32(bytes: [0x0F, 0x38, 0x0F, 0xFF])!
    )
    
    static let pocket = ColourPalette(
        colour0: UInt32(bytes: [0xFF, 0xFF, 0xFF, 0xFF])!,
        colour1: UInt32(bytes: [0xA9, 0xA9, 0xA9, 0xFF])!,
        colour2: UInt32(bytes: [0x54, 0x54, 0x54, 0xFF])!,
        colour3: UInt32(bytes: [0x0F, 0x38, 0x0F, 0xFF])!
    )
}

// MARK: - Constants

extension ColourPalette {
    private static let bitsPerColourID: UInt8 = 2
    private static let bitMask: UInt8 = 0b11
    
    private static let colourId1: UInt8 = 0b00
    private static let colourId2: UInt8 = 0b01
    private static let colourId3: UInt8 = 0b10
    private static let colourId4: UInt8 = 0b11
}
