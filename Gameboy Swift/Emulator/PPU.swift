//
//  PPU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 28/8/21.
//

import Foundation
import Cocoa


class PPU {
   
    private var vRam = Array(repeating: UInt8.min, count: vRamSize)
    
    private var scanlineTimer = 0
    var currentScanlineIndex: UInt8 = 0 // LY
    var coincidenceRegister: UInt8 = 0 // LYC
    var statusRegister: UInt8 = 0 // LCDS
    var controlRegister: UInt8 = 0 // LCDC
    
    var screenData: [ColourPalette.PixelData] = Array(
        repeating: .init(id: 0, palette: 0),
        count: pixelHeight * pixelWidth
    )
    
    func readVRAM(globalAddress: UInt16) -> UInt8 {
        let vRamAddress = globalAddress &- Memory.videoRamAddressRange.lowerBound
        return vRam[vRamAddress]
    }
    
    func writeVRAM(globalAddress: UInt16, value: UInt8) {
        let vRamAddress = globalAddress &- Memory.videoRamAddressRange.lowerBound
        vRam[vRamAddress] = value
    }
    
    func tick(tCycles: Int) {
        
        let isLCDEnabled = controlRegister.checkBit(Memory.lcdAndPpuEnabledBitIndex)
        guard isLCDEnabled else {
            updateDisabledLCDStatus()
            return
        }
        
        updateEnabledLCDStatus()
        
        scanlineTimer += tCycles
        if scanlineTimer >= Self.tCyclesPerScanline {
            scanlineTimer -= Self.tCyclesPerScanline
            
            switch currentScanlineIndex {
            case ...Self.lastVisibleScanlineIndex:
                drawScanline()
                
            case Self.lastVisibleScanlineIndex &+ 1:
                GameBoy.instance.mmu.requestVBlankInterrupt()
                
            default:
                break
            }
            
            currentScanlineIndex += 1
            if currentScanlineIndex > Self.lastAbsoluteScanlineIndex {
                currentScanlineIndex = 0
            }
        }
    }
    
    private func updateDisabledLCDStatus() {
        // LCD is disabled, so reset scanline and set mode to vBlank.
        scanlineTimer = 0
        currentScanlineIndex = 0
        
        statusRegister &= ~Self.lcdModeMask
        statusRegister |= Self.vBlankMode
        return
    }
    
    private func updateEnabledLCDStatus() {
        let currentLCDMode = statusRegister & Self.lcdModeMask
        
        var newLCDMode: UInt8
        var interruptRequired: Bool
        
        // Clear the current mode
        statusRegister &= ~Self.lcdModeMask
        
        if currentScanlineIndex > Self.lastVisibleScanlineIndex {
            newLCDMode = Self.vBlankMode
            statusRegister |= newLCDMode
            interruptRequired = statusRegister.checkBit(Memory.vBlankInterruptEnabledBitIndex)
        } else {
            switch scanlineTimer {
            case Self.searchingOAMPeriodTCycles: // First 20 M-Cycles / 80 Clock Cycles
                newLCDMode = Self.searchingOAMMode
                statusRegister |= newLCDMode
                interruptRequired = statusRegister.checkBit(Memory.searchingOAMBitIndex)
                
            case Self.transferringDataToLCDPeriodTCycles: // Next 43 M-Cycles / 172 Clock Cycles
                newLCDMode = Self.transferringDataToLCDMode
                statusRegister |= newLCDMode
                interruptRequired = false
                
            default:
                newLCDMode = Self.hBlankMode
                statusRegister |= newLCDMode
                interruptRequired = statusRegister.checkBit(Memory.hBlankInterruptEnabledBitIndex)
            }
        }
        
        // Request interrupt if required
        if interruptRequired && (newLCDMode != currentLCDMode) {
            GameBoy.instance.mmu.requestLCDInterrupt()
        }
        
        // Check the conicidence flag
        if currentScanlineIndex == coincidenceRegister {
            statusRegister.setBit(Memory.coincidenceBitIndex)
            if statusRegister.checkBit(Memory.coincidenceInterruptEnabledBitIndex) {
                GameBoy.instance.mmu.requestLCDInterrupt()
            }
        } else {
            statusRegister.clearBit(Memory.coincidenceBitIndex)
        }
    }
}

// MARK: - Scanline Rendering

extension PPU {
    
    private func drawScanline() {
        // Don't bother rendering if scanline is off screen
        guard (currentScanlineIndex < Self.pixelHeight) else { return }
        
        let renderTilesAndWindowEnabled = controlRegister.checkBit(Memory.bgAndWindowEnabledBitIndex)
        let renderSpritesEnabled = controlRegister.checkBit(Memory.objectsEnabledBitIndex)
        
        if renderTilesAndWindowEnabled {
            renderBackground()
        }
        
        if renderTilesAndWindowEnabled {
            renderWindow()
        }
        
        if renderSpritesEnabled {
            renderSprites()
        }
    }
    
    private func renderBackground() {
        let scrollY = GameBoy.instance.mmu.safeReadValue(globalAddress: Memory.addressScrollY)
        let scrollX = GameBoy.instance.mmu.safeReadValue(globalAddress: Memory.addressScrollX)
        let palette = GameBoy.instance.mmu.safeReadValue(globalAddress: Memory.addressBgPalette)

        // Check which area of tile data we are using
        let isUsingTileDataAddress1 = controlRegister.checkBit(Memory.bgAndWindowTileDataAreaBitIndex)
        
        // Check which area of background data we are using
        let addressBgArea = controlRegister.checkBit(Memory.bgTileMapAreaBitIndex) ? Memory.addressBgAndWindowArea1 : Memory.addressBgAndWindowArea2
        
        // Get Y coordinate relative to background space
        let relativeYCo = currentScanlineIndex &+ scrollY
        
        // Get row index of tile from row of 32 tiles
        let tileRowIndex = relativeYCo >> 3 // Equivalent to `relativeYCo/8`
        let tileRowIndexAddress: UInt16 = addressBgArea &+ (UInt16(tileRowIndex) &* Self.tilesPerRow)
        
        // Convenience
        let pixelRowIndex = (relativeYCo & 7) &* Self.bytesPerPixelRow // Equivalent to `Int(relativeYCo % 8) &* Self.bytesPerPixelRow
        let tilePixelOffset = Int(scrollX & 7) // Equivalent to `scollX % 8`
        
        // Iterate through minimum amount of tiles that we need to grab from memory
        for scanlineTileIndex in 0..<Self.maxTilesPerScanline {
            
            // Get memory address of tile
            let firstPixelIndexOfTile = scanlineTileIndex &* Self.pixelsPerTileRow
            let relativeTileColumnIndex = (firstPixelIndexOfTile &+ scrollX) >> 3 // Equivalent to `(firstPixelIndexOfTile &+ scrollX) / 8`
            let tileIndexAddress: UInt16 = tileRowIndexAddress &+ UInt16(relativeTileColumnIndex)
            let tileAddress: UInt16 = getTileAddress(tileIndexAddress: tileIndexAddress, isUsingTileDataAddress1: isUsingTileDataAddress1)
            
            // Find which of the tile's pixel rows we are on and get the pixel row data from memory
            let pixelRowAddress = tileAddress &+ UInt16(pixelRowIndex)
            let rowData1 = readVRAM(globalAddress: pixelRowAddress)
            let rowData2 = readVRAM(globalAddress: pixelRowAddress &+ 1)
            
            for pixelIndex in Self.tileRowPixelIndices {
                let scanlinePixelIndex = Int(firstPixelIndexOfTile) + pixelIndex - tilePixelOffset
                guard Self.visibleScanlinePixelsRange.contains(scanlinePixelIndex) else { continue }
                
                // Use colour ID to get colour from palette
                let colourID = getColourId(pixelIndex: pixelIndex, rowData1: rowData1, rowData2: rowData2, flipX: false)
                
                let pixelData = ColourPalette.PixelData(id: colourID, palette: palette)
                let globalPixelIndex = Int(currentScanlineIndex) * Self.pixelWidth + scanlinePixelIndex
                screenData[globalPixelIndex] = pixelData
            }
        }
    }
    
    private func renderWindow() {
        let windowEnabled = controlRegister.checkBit(Memory.windowEnabledBitIndex)
        guard windowEnabled else { return }
        
        let windowY = GameBoy.instance.mmu.safeReadValue(globalAddress: Memory.addressWindowY)
        let isScanlineWithinWindowBounds = currentScanlineIndex >= windowY
        guard isScanlineWithinWindowBounds else { return }
    
        // Check which area of tile data we are using
        let isUsingTileDataAddress1 = controlRegister.checkBit(Memory.bgAndWindowTileDataAreaBitIndex)
        
        // Check which area of window data we are using
        let addressWindowArea = controlRegister.checkBit(Memory.windowTileMapAreaBitIndex) ? Memory.addressBgAndWindowArea1 : Memory.addressBgAndWindowArea2
        
        // Get Y coordinate relative to window space
        let relativeYCo = currentScanlineIndex &- windowY
        
        // Get row index of tile from row of 32 tiles
        let tileRowIndex = relativeYCo >> 3 // Equivalent to `relativeYCo/8`
        let tileRowIndexAddress: UInt16 = addressWindowArea &+ (UInt16(tileRowIndex) &* Self.tilesPerRow)
        
        let pixelRowIndex = (relativeYCo & 7) &* Self.bytesPerPixelRow // Equivalent to `Int(relativeYCo % 8) &* Self.bytesPerPixelRow
        let palette = GameBoy.instance.mmu.safeReadValue(globalAddress: Memory.addressBgPalette)
        let windowX = GameBoy.instance.mmu.safeReadValue(globalAddress: Memory.addressWindowX) &- Self.windowXOffset
        
        // Iterate through minimum amount of tiles that we need to grab from memory
        for scanlineTileIndex in 0..<Self.maxTilesPerScanline {
            
            let firstPixelIndexOfTile = scanlineTileIndex &* Self.pixelsPerTileRow &+ windowX

            // Get memory address of tile
            let tileIndexAddress: UInt16 = tileRowIndexAddress &+ UInt16(scanlineTileIndex)
            let tileAddress: UInt16 = getTileAddress(tileIndexAddress: tileIndexAddress, isUsingTileDataAddress1: isUsingTileDataAddress1)
            
            // Find which of the tile's pixel rows we are on and get the pixel row data from memory
            let pixelRowAddress = tileAddress &+ UInt16(pixelRowIndex)
            let rowData1 = readVRAM(globalAddress: pixelRowAddress)
            let rowData2 = readVRAM(globalAddress: pixelRowAddress &+ 1)
            
            for pixelIndex in Self.tileRowPixelIndices {
                let scanlinePixelIndex = Int(firstPixelIndexOfTile) + pixelIndex
                guard Self.visibleScanlinePixelsRange.contains(scanlinePixelIndex) else { continue }
                
                // Use colour ID to get colour from palette
                let colourID = getColourId(pixelIndex: pixelIndex, rowData1: rowData1, rowData2: rowData2, flipX: false)
                let pixelData = ColourPalette.PixelData(id: colourID, palette: palette)
                let globalPixelIndex = Int(currentScanlineIndex) * Self.pixelWidth + scanlinePixelIndex
                screenData[globalPixelIndex] = pixelData
            }
        }
    }
    
    private func renderSprites() {
        let areLargeSprites = controlRegister.checkBit(Memory.objectSizeBitIndex)
        let spriteHeight = areLargeSprites ? Self.largeSpriteHeight : Self.smallSpriteHeight
        
        // TODO: Implement sprite priority
        // DMG: Sprite with lower xCo is drawn over the top of the others
        // GBC: Sprite with higher? OAM index is drawn over the top of the others
        
        for spriteIndex in 0..<Self.maxNumberOfSprites {
            let spriteIndexOffset = spriteIndex &* Self.bytesPerSprite
            let spriteDataAddress = Memory.addressOAM &+ spriteIndexOffset
            
            // Sprite Data Property Addresses
            let spriteDataYCoAddress = spriteDataAddress
            let spriteDataXCoAddress = spriteDataAddress &+ 1
            let spriteDataTileIndexAddress = spriteDataAddress &+ 2
            let spriteDataAttributesAddress = spriteDataAddress &+ 3
            
            let yCo = GameBoy.instance.mmu.safeReadValue(globalAddress: spriteDataYCoAddress) &- Self.spriteYOffset
            let xCo = GameBoy.instance.mmu.safeReadValue(globalAddress: spriteDataXCoAddress) &- Self.spriteXOffset
            
            let spriteBoundsLower = Int(yCo)
            let spriteBoundsUpper = spriteBoundsLower + spriteHeight
            let spriteBounds = spriteBoundsLower..<spriteBoundsUpper
            
            // Check if sprite intercepts with scanline
            guard spriteBounds.contains(Int(currentScanlineIndex)) else { continue }
                
            let attributes = GameBoy.instance.mmu.safeReadValue(globalAddress: spriteDataAttributesAddress)
            let renderAboveBackground = !attributes.checkBit(Memory.bgAndWindowOverObjBitIndex)
            let flipY = attributes.checkBit(Memory.yFlipBitIndex)
            let flipX = attributes.checkBit(Memory.xFlipBitIndex)
            let colourAddress = attributes.checkBit(Memory.paletteNumberBitIndex) ? Memory.addressObjPalette2 : Memory.addressObjPalette1
            
            let palette = GameBoy.instance.mmu.safeReadValue(globalAddress: colourAddress)
            
            var spriteRowIndex = currentScanlineIndex &- yCo
            if flipY {
                spriteRowIndex = 7 - spriteRowIndex
            }

            spriteRowIndex &*= Self.bytesPerPixelRow
            let tileIndex = GameBoy.instance.mmu.safeReadValue(globalAddress: spriteDataTileIndexAddress)
            let tileIndexAddress = Memory.addressTileArea1 &+ (UInt16(tileIndex) &* Self.bytesPerTile)
            let dataAddress = tileIndexAddress &+ UInt16(spriteRowIndex)
            let rowData1 = readVRAM(globalAddress: dataAddress)
            let rowData2 = readVRAM(globalAddress: dataAddress &+ 1)
            
            let pixelIndices = 0...UInt8.bitWidth-1
            for pixelIndex in pixelIndices {

                let colourID = getColourId(pixelIndex: pixelIndex, rowData1: rowData1, rowData2: rowData2, flipX: flipX)
                
                // Colour ID 0 is transparent for sprites
                guard colourID != 0 else { continue }

                let globalXco = Int(xCo) &+ pixelIndex
                let screenDataIndex = Int(currentScanlineIndex) * Self.pixelWidth + Int(globalXco)
                guard screenDataIndex < screenData.count else { return }
                
                let pixelData = ColourPalette.PixelData(id: colourID, palette: palette)
                
                if renderAboveBackground {
                    screenData[screenDataIndex] = pixelData
                } else {
                    // If not rendering above background, then sprite can only show through where the background pixel colour id is 0.
                    // NOTE: The window is currently being rendered before the sprites, so I am not sure if that affects this.
                    let backgroundPixelData = screenData[screenDataIndex]
                    if backgroundPixelData.id == 0 {
                        screenData[screenDataIndex] = pixelData
                    }
                }
            }
        }
    }
    
    private func getTileAddress(tileIndexAddress: UInt16, isUsingTileDataAddress1: Bool) -> UInt16 {
        let tileIndex = readVRAM(globalAddress: tileIndexAddress)
        if isUsingTileDataAddress1 {
            // Tile Data Address 1 indexes using unsigned integer
            let tileAddressOffset = UInt16(tileIndex) &* Self.bytesPerTile
            return Memory.addressTileArea1 &+ tileAddressOffset
        } else {
            // Tile Data Address 2 indexes using signed integer
            let signedTileIndex = Int8(bitPattern: tileIndex)
            // Originates from UInt8 so guaranteed to be positive after adding 128
            let convertedTileIndex = Int16(signedTileIndex) &+ 128
            let tileAddressOffset = convertedTileIndex.magnitude &* Self.bytesPerTile
            return Memory.addressTileArea2 &+ tileAddressOffset
        }
    }
    
    private func getColourId(pixelIndex: Int, rowData1: UInt8, rowData2: UInt8, flipX: Bool) -> UInt8 {
        var adjustedPixelIndex = pixelIndex
        
        if !flipX {
            switch adjustedPixelIndex {
            case 0: adjustedPixelIndex = 7
            case 1: adjustedPixelIndex = 6
            case 2: adjustedPixelIndex = 5
            case 3: adjustedPixelIndex = 4
            case 4: adjustedPixelIndex = 3
            case 5: adjustedPixelIndex = 2
            case 6: adjustedPixelIndex = 1
            case 7: adjustedPixelIndex = 0
            default: fatalError()
            }
        }
        let colourID = (rowData2.getBitValue(adjustedPixelIndex) << 1) | rowData1.getBitValue(adjustedPixelIndex)
        return colourID
    }
}

// MARK: - Constants

extension PPU {
    
    // VRAM
    private static let vRamSize = 8 * 1024 // 8KB
    
    // Resolution
    private static let pixelWidth = 160
    private static let pixelHeight = 144
    
    // Scanlines
    private static let visibleScanlinePixelsRange: ClosedRange<Int> = 0...pixelWidth-1
    private static let lastVisibleScanlineIndex: UInt8 = 143
    private static let lastAbsoluteScanlineIndex: UInt8 = 153
    
    // Scanline Timing Periods
    private static let tCyclesPerScanline = 456
    private static let searchingOAMPeriodTCycles: ClosedRange<Int> = 0...79
    private static let transferringDataToLCDPeriodTCycles: ClosedRange<Int> = 80...247
    
    // LCD Modes
    private static let lcdModeMask: UInt8 = 0b00000011
    private static let hBlankMode: UInt8 = 0b00
    private static let vBlankMode: UInt8 = 0b01
    private static let searchingOAMMode: UInt8 = 0b10
    private static let transferringDataToLCDMode: UInt8 = 0b11
    
    // Tiles
    private static let pixelsPerTileRow: UInt8 = 8
    private static let bytesPerPixelRow: UInt8 = 2
    private static let bytesPerTile: UInt16 = 16
    private static let tilesPerRow: UInt16 = 32
    private static let maxTilesPerScanline: UInt8 = 21 // Is 21 due to X-axis scroll. 19 complete tiles + two incomplete tiles.
    private static let tileRowPixelIndices = 0...Int(pixelsPerTileRow)-1
    
    // Sprites
    private static let maxNumberOfSprites: UInt16 = 40
    private static let bytesPerSprite: UInt16 = 4
    private static let spriteXOffset: UInt8 = 8
    private static let spriteYOffset: UInt8 = 16
    private static let smallSpriteHeight: Int = 8
    private static let largeSpriteHeight: Int = 16
    
    // Miscellaneous
    private static let windowXOffset: UInt8 = 7
}
