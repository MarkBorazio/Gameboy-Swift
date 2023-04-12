//
//  PPU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 28/8/21.
//

import Foundation
import Cocoa

class PPU {
    
    static let shared = PPU()
    
    private var scanlineTimer = 0
  
    var screenData: [ColourPalette.PixelData] = Array(
        repeating: .init(id: 0, palette: 0),
        count: Int(pixelHeight) * Int(pixelWidth)
    )
    
    func tick(cycles: Int) {
        guard MMU.shared.isLCDEnabled else {
            updateDisabledLCDStatus()
            return
        }
        
        updateEnabledLCDStatus()
        
        scanlineTimer += cycles
        if scanlineTimer >= Self.machineCyclesPerScanline {
            scanlineTimer = 0
            
            var currentScanlineIndex = MMU.shared.currentScanline
            
            switch currentScanlineIndex {
            case ...Self.lastVisibleScanlineIndex:
                drawScanline()
                
            case Self.lastVisibleScanlineIndex &+ 1:
                MMU.shared.requestVBlankInterrupt()
                
            default:
                break
            }
            
            currentScanlineIndex &+= 1
            if currentScanlineIndex > Self.lastAbsoluteScanlineIndex {
                currentScanlineIndex = 0
            }
            MMU.shared.currentScanline = currentScanlineIndex
        }
    }
    
    private func updateDisabledLCDStatus() {
        // LCD is disabled, so reset scanline and set mode to vBlank.
        scanlineTimer = 0
        MMU.shared.currentScanline = 0
        
        var status = MMU.shared.readValue(address: Memory.addressLCDS)
        status &= ~Self.lcdModeMask
        status |= Self.vBlankMode
        MMU.shared.writeValue(status, address: Memory.addressLCDS)
        return
    }
    
    private func updateEnabledLCDStatus() {
        var status = MMU.shared.readValue(address: Memory.addressLCDS)
        let currentScanlineIndex = MMU.shared.currentScanline
        let currentLCDMode = status & Self.lcdModeMask
        
        var newLCDMode: UInt8
        var interruptRequired: Bool
        
        // Clear the current mode
        status &= ~Self.lcdModeMask
        
        if currentScanlineIndex > Self.lastVisibleScanlineIndex {
            newLCDMode = Self.vBlankMode
            status |= newLCDMode
            interruptRequired = status.checkBit(Memory.vBlankInterruptEnabledBitIndex)
        } else {
            if Self.searchingOAMPeriod ~= scanlineTimer { // First 20 M-Cycles / 80 Clock Cycles
                newLCDMode = Self.searchingOAMMode
                status |= newLCDMode
                interruptRequired = status.checkBit(Memory.searchingOAMBitIndex)
            } else if Self.transferringDataToLCDPeriod ~= scanlineTimer { // Next 43 M-Cycles / 172 Clock Cycles
                newLCDMode = Self.transferringDataToLCDMode
                status |= newLCDMode
                interruptRequired = false
            } else { // Remaining M-Cycles
                newLCDMode = Self.hBlankMode
                status |= newLCDMode
                interruptRequired = status.checkBit(Memory.hBlankInterruptEnabledBitIndex)
            }
        }
        
        // Request interrupt if required
        if interruptRequired && (newLCDMode != currentLCDMode) {
            MMU.shared.requestLCDInterrupt()
        }
        
        // Check the conicidence flag
        let lyRegister = MMU.shared.readValue(address: Memory.addressLY)
        let lycRegister = MMU.shared.readValue(address: Memory.addressLYC)
        if lyRegister == lycRegister {
            status.setBit(Memory.coincidenceBitIndex)
            if status.checkBit(Memory.coincidenceInterruptEnabledBitIndex) {
                MMU.shared.requestLCDInterrupt()
            }
        } else {
            status.clearBit(Memory.coincidenceBitIndex)
        }
        
        MMU.shared.writeValue(status, address: Memory.addressLCDS)
    }
    
    private func drawScanline() {
        let control = UInt8.max //MMU.shared.readValue(address: MMU.addressLCDC)
        
        // TODO: Consider rendering background layer, and then window layer separately over the top
        if control.checkBit(Memory.bgAndWindowEnabledBitIndex) {
            renderTiles()
        }
        
        if control.checkBit(Memory.objectsEnabledBitIndex) {
            renderSprites()
        }
    }
    
    // Ref: http://www.codeslinger.co.uk/pages/projects/gameboy/graphics.html
    private func renderTiles() {
        
        let currentScanline = MMU.shared.currentScanline
        
        // Don't bother rendering if scanline is off screen
        guard (0..<Self.pixelHeight ~= currentScanline) else {
            return
        }
        
        let scrollY = MMU.shared.readValue(address: Memory.addressScrollY)
        let scrollX = MMU.shared.readValue(address: Memory.addressScrollX)
        let windowY = MMU.shared.readValue(address: Memory.addressWindowY)
        let windowX = MMU.shared.readValue(address: Memory.addressWindowX) &- Self.windowXOffset
        let control = MMU.shared.readValue(address: Memory.addressLCDC)
        
        // Check if we are rendering the window
        let windowEnabled = control.checkBit(Memory.windowEnabledBitIndex)
        let isScanlineWithinWindowBounds = windowY <= currentScanline
        let isRenderingWindow = windowEnabled && isScanlineWithinWindowBounds
        
        // Check which area of tile data we are using
        let isUsingTileDataAddress1 = control.checkBit(Memory.bgAndWindowTileDataAreaBitIndex)
        
        // Check which area of background data we are using
        let addressBgAndWindowBitIndex = isRenderingWindow ? Memory.windowTileMapAreaBitIndex : Memory.bgTileMapAreaBitIndex
        let addressBgAndWindowArea = control.checkBit(addressBgAndWindowBitIndex) ? Memory.addressBgAndWindowArea1 : Memory.addressBgAndWindowArea2
        
        // Get Y coordinate relative to window or background space
        let relativeYCo = isRenderingWindow ? (currentScanline &- windowY) : (currentScanline &+ scrollY)
        
        // Get row index of tile from row of 32 tiles
        let tileRowIndex = relativeYCo/8
        
        // Draw 160 horizontal pixels for scanline
        for scanlinePixelIndex in 0..<Self.pixelWidth {
            
            // Get X coordinate relative to window or background space
            // TODO: Confirm if this is correct. It seems that we can have a y-coordinate relative to the window
            // space, but an x-coordinate relative to the background space. That seems wrong.
            // Update: It's probably correct, actually. The window is rendered on top of the background, so
            // we could move from drawing a background pixel to drawing a window pixel in the same scanline.
            let isPixelIndexWithinWindowXBounds = scanlinePixelIndex >= windowX
            let shouldUseWindowSpaceForXCo = isRenderingWindow && isPixelIndexWithinWindowXBounds
            let relativeXCo = shouldUseWindowSpaceForXCo ? (scanlinePixelIndex &- windowX) : (scanlinePixelIndex &+ scrollX)
            
            // Get column index of tile from column of 32 tiles
            let tileColumnIndex = relativeXCo/8
            
            // Get memory index of tile
            let tileIndexAddress: UInt16 = addressBgAndWindowArea
                &+ (UInt16(tileRowIndex) &* Self.tilesPerRow)
                &+ UInt16(tileColumnIndex)
            let tileIndex = MMU.shared.readValue(address: tileIndexAddress)
            
            // Get memory address of tile
            let tileAddress: UInt16
            if isUsingTileDataAddress1 {
                // Tile Data Address 1 indexes using unsigned integer
                let tileAddressOffset = UInt16(tileIndex) &* Self.bytesPerTile
                tileAddress = Memory.addressTileArea1 &+ tileAddressOffset
            } else {
                // Tile Data Address 2 indexes using signed integer
                let signedTileIndex = Int8(bitPattern: tileIndex)
                // Originates from UInt8 so guaranteed to be positive after adding 128
                let convertedTileIndex = Int16(signedTileIndex) &+ 128
                let tileAddressOffset = convertedTileIndex.magnitude &* Self.bytesPerTile
                tileAddress = Memory.addressTileArea2 &+ tileAddressOffset
            }
            
            // Find which of the tile's pixel rows we are on and get the pixel row data from memory
            let pixelRowIndex = (relativeYCo % 8) &* Self.bytesPerPixelRow
            let pixelRowAddress = tileAddress &+ UInt16(pixelRowIndex)
            let rowData1 = MMU.shared.readValue(address: pixelRowAddress)
            let rowData2 = MMU.shared.readValue(address: pixelRowAddress &+ 1)

            // Get the colour ID of the pixel
            let bitIndex = Int(relativeXCo % 8)
            
            // Adjust pixel row data to align bit indices with pixel indices.
            // Pixel 0 corresponds to bit 7 of rowData1 and rowData2,
            // pixel 1 corresponds to bit 6 of rowData1 and rowData2,
            // etc.
            // I could reverse the bits, but that isn't performant.
            let adjustedBitIndex: Int
            switch bitIndex {
            case 0: adjustedBitIndex = 7
            case 1: adjustedBitIndex = 6
            case 2: adjustedBitIndex = 5
            case 3: adjustedBitIndex = 4
            case 4: adjustedBitIndex = 3
            case 5: adjustedBitIndex = 2
            case 6: adjustedBitIndex = 1
            case 7: adjustedBitIndex = 0
            default: adjustedBitIndex = 0
            }
            let colourID = (rowData2.getBitValue(adjustedBitIndex) << 1) | rowData1.getBitValue(adjustedBitIndex)
            
            // Use colour ID to get colour from palette
            let palette = MMU.shared.readValue(address: Memory.addressBgPalette)
            let pixelData = ColourPalette.PixelData(id: colourID, palette: palette)
            
            let globalPixelIndex = Int(currentScanline) * Int(Self.pixelWidth) + Int(scanlinePixelIndex)
            
            screenData[globalPixelIndex] = pixelData
        }
    }
    
    private func renderSprites() {
        let scanline = MMU.shared.currentScanline
        let control = MMU.shared.readValue(address: Memory.addressLCDC)
        let areLargeSprites = control.checkBit(Memory.objectSizeBitIndex)
        
        for spriteIndex in 0..<Self.maxNumberOfSprites {
            let spriteIndexOffset = spriteIndex &* Self.bytesPerSprite
            let spriteDataAddress = Memory.addressOAM &+ UInt16(spriteIndexOffset)
            let yCo = MMU.shared.readValue(address: spriteDataAddress) &- Self.spriteYOffset
            let xCo = MMU.shared.readValue(address: spriteDataAddress &+ 1) &- Self.spriteXOffset
            let tileIndex = MMU.shared.readValue(address: spriteDataAddress &+ 2)
            let attributes = MMU.shared.readValue(address: spriteDataAddress &+ 3)
            
            let flipY = attributes.checkBit(Memory.yFlipBitIndex)
            let flipX = attributes.checkBit(Memory.xFlipBitIndex)
            
            let spriteHeight: UInt8 = areLargeSprites ? Self.largeSpriteHeight : Self.smallSpriteHeight
            let spriteBoundsLower = Int(yCo)
            let spriteBoundsUpper = Int(yCo) + Int(spriteHeight)
            let spriteBounds = spriteBoundsLower..<spriteBoundsUpper
            
            // Check if sprite intercepts with scanline
            if spriteBounds ~= Int(scanline) {
                var spriteRowIndex = scanline &- yCo
                
                if flipY {
                    spriteRowIndex = 7 - spriteRowIndex
                }

                spriteRowIndex &*= Self.bytesPerPixelRow
                let dataAddress = Memory.addressTileArea1
                    &+ (UInt16(tileIndex) &* Self.bytesPerTile)
                    &+ UInt16(spriteRowIndex)
                let data1 = MMU.shared.readValue(address: dataAddress)
                let data2 = MMU.shared.readValue(address: dataAddress &+ 1)
                
                // Reverse since it's easier to read from right to left due to colour data
                let reversedPixelIndices = (0...UInt8.bitWidth-1).reversed()
                for pixelIndex in reversedPixelIndices {
                    var colourBitIndex = Int(pixelIndex)
                    
                    if flipX {
                        colourBitIndex = 7 - colourBitIndex
                    }
                    
                    let colourID = (data2.getBitValue(colourBitIndex) << 1) | data1.getBitValue(colourBitIndex)
                    let colourAddress = attributes.checkBit(Memory.paletteNumberBitIndex) ? Memory.addressObjPalette2 : Memory.addressObjPalette1
                    let palette = MMU.shared.readValue(address: colourAddress)
                    let pixelData = ColourPalette.PixelData(id: colourID, palette: palette)
                    
                    // White is transparent for sprites (supposedly...)
                    if pixelData.colourId == ColourPalette.whiteColourId {
                        continue
                    }
                    
                    let readjustedPixelIndex = 7 - pixelIndex // Since we looped in reverese order
                    let globalXco = Int(xCo) &+ readjustedPixelIndex
                    
                    // Sanity check... cbf
                    let index = Int(scanline) * Int(Self.pixelWidth) + Int(globalXco)
                    screenData[index] = pixelData
                }
            }
        }
    }
}

// MARK: - Constants

extension PPU {
    
    // Resolution
    private static let pixelWidth: UInt8 = 160
    private static let pixelHeight: UInt8 = 144
    
    // Scanlines
    private static let lastVisibleScanlineIndex: UInt8 = 143
    private static let lastAbsoluteScanlineIndex: UInt8 = 153
    
    // Scanline Timing Periods
    private static let machineCyclesPerScanline = 114 // 456 clock cycles
    private static let searchingOAMPeriod: ClosedRange<Int> = 0...19 // First 20 M-Cycles
    private static let transferringDataToLCDPeriod: ClosedRange<Int> = 20...62 // Next 43 M-Cycles
    
    // LCD Modes
    private static let lcdModeMask: UInt8 = 0b00000011
    private static let hBlankMode: UInt8 = 0b00
    private static let vBlankMode: UInt8 = 0b01
    private static let searchingOAMMode: UInt8 = 0b10
    private static let transferringDataToLCDMode: UInt8 = 0b11
    
    // Tiles
    private static let bytesPerTile: UInt16 = 16
    private static let bytesPerPixelRow: UInt8 = 2
    private static let tilesPerRow: UInt16 = 32
    
    // Sprites
    private static let maxNumberOfSprites = 40
    private static let bytesPerSprite = 4
    private static let spriteXOffset: UInt8 = 8
    private static let spriteYOffset: UInt8 = 16
    private static let smallSpriteHeight: UInt8 = 8
    private static let largeSpriteHeight: UInt8 = 16
    
    // Miscellaneous
    private static let windowXOffset: UInt8 = 7
}
