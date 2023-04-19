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
        let status = MMU.shared.readValue(address: Memory.addressLCDS)
        
        guard MMU.shared.isLCDEnabled else {
            updateDisabledLCDStatus(currentStatus: status)
            return
        }
        
        var currentScanlineIndex = MMU.shared.getScanline()
        updateEnabledLCDStatus(currentScanlineIndex: currentScanlineIndex, currentStatus: status)
        
        scanlineTimer += cycles
        if scanlineTimer >= Self.machineCyclesPerScanline {
            scanlineTimer = 0
            
            switch currentScanlineIndex {
            case ...Self.lastVisibleScanlineIndex:
                drawScanline(scanlineIndex: currentScanlineIndex)
                
            case Self.lastVisibleScanlineIndex &+ 1:
                MMU.shared.requestVBlankInterrupt()
                
            default:
                break
            }
            
            currentScanlineIndex &+= 1
            if currentScanlineIndex > Self.lastAbsoluteScanlineIndex {
                currentScanlineIndex = 0
            }
            MMU.shared.setScanline(currentScanlineIndex)
        }
    }
    
    private func updateDisabledLCDStatus(currentStatus: UInt8) {
        // LCD is disabled, so reset scanline and set mode to vBlank.
        scanlineTimer = 0
        MMU.shared.setScanline(0)
        
        var status = currentStatus
        status &= ~Self.lcdModeMask
        status |= Self.vBlankMode
        MMU.shared.writeValue(status, address: Memory.addressLCDS)
        return
    }
    
    private func updateEnabledLCDStatus(currentScanlineIndex: UInt8, currentStatus: UInt8) {
        var status = currentStatus
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
            switch scanlineTimer {
            case Self.searchingOAMPeriod: // First 20 M-Cycles / 80 Clock Cycles
                newLCDMode = Self.searchingOAMMode
                status |= newLCDMode
                interruptRequired = status.checkBit(Memory.searchingOAMBitIndex)
                
            case Self.transferringDataToLCDPeriod: // Next 43 M-Cycles / 172 Clock Cycles
                newLCDMode = Self.transferringDataToLCDMode
                status |= newLCDMode
                interruptRequired = false
                
            default:
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
    
    private func drawScanline(scanlineIndex: UInt8) {
        let control = MMU.shared.readValue(address: Memory.addressLCDC)
        
        // TODO: Consider rendering background layer, and then window layer separately over the top
        if control.checkBit(Memory.bgAndWindowEnabledBitIndex) {
            renderTiles(scanlineIndex: scanlineIndex, control: control)
        }
        
        if control.checkBit(Memory.objectsEnabledBitIndex) {
            renderSprites(scanlineIndex: scanlineIndex, control: control)
        }
    }
    
    // Ref: http://www.codeslinger.co.uk/pages/projects/gameboy/graphics.html
    private func renderTiles(scanlineIndex: UInt8, control: UInt8) {
        // Don't bother rendering if scanline is off screen
        guard (scanlineIndex < Self.pixelHeight) else {
            return
        }
        
        let scrollY = MMU.shared.readValue(address: Memory.addressScrollY)
        let scrollX = MMU.shared.readValue(address: Memory.addressScrollX)
        let windowY = MMU.shared.readValue(address: Memory.addressWindowY)
        let windowX = MMU.shared.readValue(address: Memory.addressWindowX) &- Self.windowXOffset
        let palette = MMU.shared.readValue(address: Memory.addressBgPalette)
        
        // Check if we are rendering the window
        let windowEnabled = control.checkBit(Memory.windowEnabledBitIndex)
        let isScanlineWithinWindowBounds = windowY <= scanlineIndex
        let isRenderingWindow = windowEnabled && isScanlineWithinWindowBounds
        
        // Check which area of tile data we are using
        let isUsingTileDataAddress1 = control.checkBit(Memory.bgAndWindowTileDataAreaBitIndex)
        
        // Check which area of background data we are using
        let addressBgAndWindowBitIndex = isRenderingWindow ? Memory.windowTileMapAreaBitIndex : Memory.bgTileMapAreaBitIndex
        let addressBgAndWindowArea = control.checkBit(addressBgAndWindowBitIndex) ? Memory.addressBgAndWindowArea1 : Memory.addressBgAndWindowArea2
        
        // Get Y coordinate relative to window or background space
        let relativeYCo = isRenderingWindow ? (scanlineIndex &- windowY) : (scanlineIndex &+ scrollY)
        
        // Get row index of tile from row of 32 tiles
        let tileRowIndex = relativeYCo >> 3 // Equivalent to `relativeYCo/8`
        let tileRowIndexAddress: UInt16 = addressBgAndWindowArea &+ (UInt16(tileRowIndex) &* Self.tilesPerRow)
        
        let pixelRowIndex = (relativeYCo & 7) &* Self.bytesPerPixelRow // Equivalent to `Int(relativeYCo % 8) &* Self.bytesPerPixelRow
        
        let renderedPixelsRange = Int(scrollX)..<(Int(scrollX) + Int(Self.pixelWidth)) // Use Ints to prevent overflow
        
        // 160 horizontal pixels for scanline
        // 8 horiztonal pixels per tile
        // Either 20 full tiles per scanline, or 19 full tiles + parts of two other tiles (due to scroll)
        for firstTilePixel in stride(from: 0, through: Self.pixelWidth, by: Self.pixelsPerTileRow) {
            
            // TODO: First, fix horiztonal scrolling issue.
            // TODO: Then, re-implement window rendering.
            
//            // Get X coordinate relative to window or background space
//            // TODO: Confirm if this is correct. It seems that we can have a y-coordinate relative to the window
//            // space, but an x-coordinate relative to the background space. That seems wrong.
//            // Update: It's probably correct, actually. The window is rendered on top of the background, so
//            // we could move from drawing a background pixel to drawing a window pixel in the same scanline.
//            let isPixelIndexWithinWindowXBounds = scanlinePixelIndex >= windowX
//            let shouldUseWindowSpaceForXCo = isRenderingWindow && isPixelIndexWithinWindowXBounds
//            let relativeXCo = shouldUseWindowSpaceForXCo ? (scanlinePixelIndex &- windowX) : (scanlinePixelIndex &+ scrollX)
            
            let relativeTilePixel = firstTilePixel &+ scrollX
            let tileColumnIndex = relativeTilePixel >> 3 // Equivalent to `relativeTilePixel / Self.pixelsPerTileRow`
            
            // Get memory address of tile
            let tileIndexAddress: UInt16 = tileRowIndexAddress &+ UInt16(tileColumnIndex)
            let tileAddress: UInt16 = getTileAddress(tileIndexAddress: tileIndexAddress, isUsingTileDataAddress1: isUsingTileDataAddress1)
            
            // Find which of the tile's pixel rows we are on and get the pixel row data from memory
            let pixelRowAddress = tileAddress &+ UInt16(pixelRowIndex)
            let rowData1 = MMU.shared.readValue(address: pixelRowAddress)
            let rowData2 = MMU.shared.readValue(address: pixelRowAddress &+ 1)
            
            let firstTilePixelOffset = Int(scrollX) & 7
            let isFirstTile = firstTilePixel == 0
            let pixelIndices = 0...UInt8.bitWidth-1
            
            for pixelIndex in pixelIndices {
                
                let scanlinePixelIndex: Int
                let tilePixelIndex: Int
                
                if isFirstTile { // First tile may be half rendered due to scrollX.
                    tilePixelIndex = pixelIndex + firstTilePixelOffset
                    scanlinePixelIndex = pixelIndex
                } else {
                    tilePixelIndex = pixelIndex
                    scanlinePixelIndex = Int(firstTilePixel) + pixelIndex - firstTilePixelOffset
                }
                
                let scrolledPixelIndex: Int = scanlinePixelIndex + Int(scrollX)
                
                guard tilePixelIndex < 8 else { continue }
                guard renderedPixelsRange.contains(scrolledPixelIndex) else { continue }

                // Use colour ID to get colour from palette
                let colourID = getColourId(tilePixelIndex: tilePixelIndex, rowData1: rowData1, rowData2: rowData2)
                let pixelData = ColourPalette.PixelData(id: colourID, palette: palette)

                let globalPixelIndex = Int(scanlineIndex) * Int(Self.pixelWidth) + Int(scanlinePixelIndex)
                screenData[globalPixelIndex] = pixelData
            }
        }
    }
    
//    // Ref: http://www.codeslinger.co.uk/pages/projects/gameboy/graphics.html
//    private func renderTiles(scanlineIndex: UInt8, control: UInt8) {
//        // Don't bother rendering if scanline is off screen
//        guard (scanlineIndex < Self.pixelHeight) else {
//            return
//        }
//
//        let scrollY = MMU.shared.readValue(address: Memory.addressScrollY)
//        let scrollX = MMU.shared.readValue(address: Memory.addressScrollX)
//        let windowY = MMU.shared.readValue(address: Memory.addressWindowY)
//        let windowX = MMU.shared.readValue(address: Memory.addressWindowX) &- Self.windowXOffset
//        let palette = MMU.shared.readValue(address: Memory.addressBgPalette)
//
//        // Check if we are rendering the window
//        let windowEnabled = control.checkBit(Memory.windowEnabledBitIndex)
//        let isScanlineWithinWindowBounds = windowY <= scanlineIndex
//        let isRenderingWindow = windowEnabled && isScanlineWithinWindowBounds
//
//        // Check which area of tile data we are using
//        let isUsingTileDataAddress1 = control.checkBit(Memory.bgAndWindowTileDataAreaBitIndex)
//
//        // Check which area of background data we are using
//        let addressBgAndWindowBitIndex = isRenderingWindow ? Memory.windowTileMapAreaBitIndex : Memory.bgTileMapAreaBitIndex
//        let addressBgAndWindowArea = control.checkBit(addressBgAndWindowBitIndex) ? Memory.addressBgAndWindowArea1 : Memory.addressBgAndWindowArea2
//
//        // Get Y coordinate relative to window or background space
//        let relativeYCo = isRenderingWindow ? (scanlineIndex &- windowY) : (scanlineIndex &+ scrollY)
//
//        // Get row index of tile from row of 32 tiles
//        let tileRowIndex = relativeYCo >> 3 // Equivalent to `relativeYCo/8`
//        let tileRowIndexAddress: UInt16 = addressBgAndWindowArea &+ (UInt16(tileRowIndex) &* Self.tilesPerRow)
//
//        let pixelRowIndex = (relativeYCo & 7) &* Self.bytesPerPixelRow // Equivalent to `Int(relativeYCo % 8) &* Self.bytesPerPixelRow`
//
//        // TODO: Get rid of this cache. It speeds things up a bit, but is still the biggest bottle neck. I need to figure out how to load a tile only once, and then draw each of it's pixels that are on screen given the scroll offset.
//        typealias TileRowData = (byte1: UInt8, byte2: UInt8)
//        var rowDataCache: [UInt8: TileRowData] = [:]
//
//        // Draw 160 horizontal pixels for scanline
//        for scanlinePixelIndex in 0..<Self.pixelWidth {
//
//            // Get X coordinate relative to window or background space
//            // TODO: Confirm if this is correct. It seems that we can have a y-coordinate relative to the window
//            // space, but an x-coordinate relative to the background space. That seems wrong.
//            // Update: It's probably correct, actually. The window is rendered on top of the background, so
//            // we could move from drawing a background pixel to drawing a window pixel in the same scanline.
//            let isPixelIndexWithinWindowXBounds = scanlinePixelIndex >= windowX
//            let shouldUseWindowSpaceForXCo = isRenderingWindow && isPixelIndexWithinWindowXBounds
//            let relativeXCo = shouldUseWindowSpaceForXCo ? (scanlinePixelIndex &- windowX) : (scanlinePixelIndex &+ scrollX)
//
//            // Get column index of tile from column of 32 tiles
//            let tileColumnIndex = relativeXCo >> 3 // Equivalent to `relativeXCo/8`
//
//            // Get the row data from cache, and if it's not in the cache, read it from memory and then store it in the cache.
//            let rowData: TileRowData
//            let optionalRowData = rowDataCache[tileColumnIndex]
//            if let optionalRowData {
//                rowData = optionalRowData
//            } else {
//                // Get memory address of tile
//                let tileIndexAddress: UInt16 = tileRowIndexAddress &+ UInt16(tileColumnIndex)
//                let tileAddress: UInt16 = getTileAddress(tileIndexAddress: tileIndexAddress, isUsingTileDataAddress1: isUsingTileDataAddress1)
//
//                // Find which of the tile's pixel rows we are on and get the pixel row data from memory
//                let pixelRowAddress = tileAddress &+ UInt16(pixelRowIndex)
//                let rowData1 = MMU.shared.readValue(address: pixelRowAddress)
//                let rowData2 = MMU.shared.readValue(address: pixelRowAddress &+ 1)
//                rowData = (rowData1, rowData2)
//                rowDataCache[tileColumnIndex] = rowData
//            }
//
//            // Get the colour ID of the pixel
//            let bitIndex = Int(relativeXCo & 7) // Equivalent to `Int(relativeXCo % 8)`
//
//            // Adjust pixel row data to align bit indices with pixel indices.
//            // Pixel 0 corresponds to bit 7 of rowData1 and rowData2,
//            // pixel 1 corresponds to bit 6 of rowData1 and rowData2,
//            // etc.
//            // I could reverse the bits, but that isn't performant.
//            let adjustedBitIndex: Int
//            switch bitIndex {
//            case 0: adjustedBitIndex = 7
//            case 1: adjustedBitIndex = 6
//            case 2: adjustedBitIndex = 5
//            case 3: adjustedBitIndex = 4
//            case 4: adjustedBitIndex = 3
//            case 5: adjustedBitIndex = 2
//            case 6: adjustedBitIndex = 1
//            case 7: adjustedBitIndex = 0
//            default: adjustedBitIndex = 0
//            }
//            let colourID = (rowData.byte2.getBitValue(adjustedBitIndex) << 1) | rowData.byte1.getBitValue(adjustedBitIndex)
//
//            // Use colour ID to get colour from palette
//            let pixelData = ColourPalette.PixelData(id: colourID, palette: palette)
//
//            let globalPixelIndex = Int(scanlineIndex) * Int(Self.pixelWidth) + Int(scanlinePixelIndex)
//
//            screenData[globalPixelIndex] = pixelData
//        }
//    }
    
    private func getTileAddress(tileIndexAddress: UInt16, isUsingTileDataAddress1: Bool) -> UInt16 {
        let tileIndex = MMU.shared.readValue(address: tileIndexAddress)
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
    
    private func getColourId(tilePixelIndex: Int, rowData1: UInt8, rowData2: UInt8) -> UInt8 {
        let adjustedBitIndex: Int
        switch tilePixelIndex {
        case 0: adjustedBitIndex = 7
        case 1: adjustedBitIndex = 6
        case 2: adjustedBitIndex = 5
        case 3: adjustedBitIndex = 4
        case 4: adjustedBitIndex = 3
        case 5: adjustedBitIndex = 2
        case 6: adjustedBitIndex = 1
        case 7: adjustedBitIndex = 0
        default: fatalError()
        }
        let colourID = (rowData2.getBitValue(adjustedBitIndex) << 1) | rowData1.getBitValue(adjustedBitIndex)
        return colourID
    }
    
    private func renderSprites(scanlineIndex: UInt8, control: UInt8) {
        let areLargeSprites = control.checkBit(Memory.objectSizeBitIndex)
        
        for spriteIndex in 0..<Self.maxNumberOfSprites {
            let spriteIndexOffset = spriteIndex &* Self.bytesPerSprite
            let spriteDataAddress = Memory.addressOAM &+ spriteIndexOffset
            
            // Sprite Data Property Addresses
            let spriteDataYCoAddress = spriteDataAddress
            let spriteDataXCoAddress = spriteDataAddress &+ 1
            let spriteDataTileIndexAddress = spriteDataAddress &+ 2
            let spriteDataAttributesAddress = spriteDataAddress &+ 3
            
            let yCo = MMU.shared.readValue(address: spriteDataYCoAddress) &- Self.spriteYOffset
            let spriteHeight = areLargeSprites ? Self.largeSpriteHeight : Self.smallSpriteHeight
            let spriteBoundsLower = Int(yCo)
            let spriteBoundsUpper = spriteBoundsLower + spriteHeight
            let spriteBounds = spriteBoundsLower..<spriteBoundsUpper
            
            // Check if sprite intercepts with scanline
            guard spriteBounds.contains(Int(scanlineIndex)) else { continue }
                
            let attributes = MMU.shared.readValue(address: spriteDataAttributesAddress)
            let flipY = attributes.checkBit(Memory.yFlipBitIndex)
            let flipX = attributes.checkBit(Memory.xFlipBitIndex)
            
            var spriteRowIndex = scanlineIndex &- yCo
            if flipY {
                spriteRowIndex = 7 - spriteRowIndex
            }

            spriteRowIndex &*= Self.bytesPerPixelRow
            let tileIndex = MMU.shared.readValue(address: spriteDataTileIndexAddress)
            let tileIndexAddress = Memory.addressTileArea1 &+ (UInt16(tileIndex) &* Self.bytesPerTile)
            let dataAddress = tileIndexAddress &+ UInt16(spriteRowIndex)
            let data1 = MMU.shared.readValue(address: dataAddress)
            let data2 = MMU.shared.readValue(address: dataAddress &+ 1)
            
            let pixelIndices = 0...UInt8.bitWidth-1
            for pixelIndex in pixelIndices {

                var colourBitIndex: Int = pixelIndex
                
                if !flipX {
                    switch colourBitIndex {
                    case 0: colourBitIndex = 7
                    case 1: colourBitIndex = 6
                    case 2: colourBitIndex = 5
                    case 3: colourBitIndex = 4
                    case 4: colourBitIndex = 3
                    case 5: colourBitIndex = 2
                    case 6: colourBitIndex = 1
                    case 7: colourBitIndex = 0
                    default: colourBitIndex = 0
                    }
                }
                
                let colourID = (data2.getBitValue(colourBitIndex) << 1) | data1.getBitValue(colourBitIndex)
                let colourAddress = attributes.checkBit(Memory.paletteNumberBitIndex) ? Memory.addressObjPalette2 : Memory.addressObjPalette1
                let palette = MMU.shared.readValue(address: colourAddress)
                let pixelData = ColourPalette.PixelData(id: colourID, palette: palette)
                
                // White is transparent for sprites (supposedly...)
                guard pixelData.colourId != ColourPalette.whiteColourId else { continue }
                
                let xCo = MMU.shared.readValue(address: spriteDataXCoAddress) &- Self.spriteXOffset
                let globalXco = Int(xCo) &+ pixelIndex
                
                let index = Int(scanlineIndex) * Int(Self.pixelWidth) + Int(globalXco)
                guard index <= screenData.count else { return }
                screenData[index] = pixelData
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
    private static let pixelsPerTileRow = 8
    private static let bytesPerPixelRow: UInt8 = 2
    private static let bytesPerTile: UInt16 = 16
    private static let tilesPerRow: UInt16 = 32
    
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
