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
    
    private var screenData: [[NSColor]] = Array(
        repeating: Array(
            repeating: ColourPalette.black,
            count: Int(pixelHeight)
        ),
        count: Int(pixelWidth)
    )
    
    func update(machineCycles: Int) {
        guard MMU.shared.isLCDEnabled else {
            updateDisabledLCDStatus()
            return
        }
        
        updateEnabledLCDStatus()
        
        scanlineTimer += machineCycles
        if scanlineTimer >= Self.machineCyclesPerScanline {
            scanlineTimer = 0
            
            MMU.shared.currentScanline += 1
            let currentScanlineIndex = MMU.shared.currentScanline
            
            if currentScanlineIndex <= Self.lastVisibleScanlineIndex { // Draw visible scanline
                drawScanline()
            }
            else if currentScanlineIndex == (Self.lastVisibleScanlineIndex + 1) { // Entered VBlank period
                MMU.shared.requestVBlankInterrupt()
            }
            else if currentScanlineIndex > Self.lastAbsoluteScanlineIndex { // Reset
                MMU.shared.currentScanline = 0
            }
        }
    }
    
    private func updateDisabledLCDStatus() {
        // LCD is disabled, so reset scanline and set mode to vBlank.
        scanlineTimer = 0
        MMU.shared.currentScanline = 0
        
        var status = MMU.shared.readValue(address: MMU.addressLCDS)
        status &= ~Self.lcdModeMask
        status |= Self.vBlankMode
        MMU.shared.writeValue(status, address: MMU.addressLCDS)
        return
    }
    
    private func updateEnabledLCDStatus() {
        var status = MMU.shared.readValue(address: MMU.addressLCDS)
        let currentScanlineIndex = MMU.shared.currentScanline
        let currentLCDMode = status & Self.lcdModeMask
        
        var newLCDMode: UInt8
        var interruptRequired: Bool
        
        if currentScanlineIndex > Self.lastVisibleScanlineIndex {
            newLCDMode = Self.vBlankMode
            status &= ~Self.lcdModeMask
            status |= Self.vBlankMode
            interruptRequired = status.checkBit(MMU.vBlankInterruptEnabledBitIndex)
        } else {
            if Self.searchingOAMPeriod ~= scanlineTimer { // First 20 M-Cycles
                newLCDMode = Self.searchingOAMMode
                status &= ~Self.lcdModeMask
                status |= Self.searchingOAMMode
                interruptRequired = status.checkBit(MMU.searchingOAMBitIndex)
            } else if Self.transferringDataToLCDPeriod ~= scanlineTimer { // Next 43 M-Cycles
                newLCDMode = Self.transferringDataToLCDMode
                status &= ~Self.lcdModeMask
                status |= Self.transferringDataToLCDMode
                interruptRequired = false
            } else { // Remaining M-Cycles
                newLCDMode = Self.hBlankMode
                status &= ~Self.lcdModeMask
                status |= Self.hBlankMode
                interruptRequired = status.checkBit(MMU.hBlankInterruptEnabledBitIndex)
            }
        }
        
        // Request interrupt if required
        if interruptRequired && (newLCDMode != currentLCDMode) {
            MMU.shared.requestLCDInterrupt()
        }
        
        // Check the conicidence flag
        let lyRegister = MMU.shared.readValue(address: MMU.addressLY)
        let lycRegister = MMU.shared.readValue(address: MMU.addressLYC)
        if lyRegister == lycRegister {
            status.setBit(MMU.coincidenceBitIndex)
            if status.checkBit(MMU.coincidenceInterruptEnabledBitIndex) {
                MMU.shared.requestLCDInterrupt()
            }
        } else {
            status.clearBit(MMU.coincidenceBitIndex)
        }
        
        MMU.shared.writeValue(status, address: MMU.addressLCDS)
    }
    
    private func drawScanline() {
        let control = MMU.shared.readValue(address: MMU.addressLCDC)
        
        // TODO: Consider rendering background layer, and then window layer separately over the top
        if control.checkBit(MMU.bgAndWindowEnabledBitIndex) {
            renderTiles()
        }
        
        if control.checkBit(MMU.objectsEnabledBitIndex) {
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
        
        let scrollY = MMU.shared.readValue(address: MMU.addressScrollY)
        let scrollX = MMU.shared.readValue(address: MMU.addressScrollX)
        let windowY = MMU.shared.readValue(address: MMU.addressWindowY)
        let windowX = MMU.shared.readValue(address: MMU.addressWindowX) - Self.windowXOffset
        let control = MMU.shared.readValue(address: MMU.addressLCDC)
        
        // Check if we are rendering the window
        let windowEnabled = control.checkBit(MMU.windowEnabledBitIndex)
        let isScanlineWithinWindowBounds = windowY <= currentScanline
        let isRenderingWindow = windowEnabled && isScanlineWithinWindowBounds
        
        // Check which area of tile data we are using
        let isUsingTileDataAddress1 = control.checkBit(MMU.bgAndWindowTileDataAreaBitIndex)
        
        // Check which area of background data we are using
        let addressBgAndWindowBitIndex = isRenderingWindow ? MMU.windowTileMapAreaBitIndex : MMU.bgTileMapAreaBitIndex
        let addressBgAndWindowArea = control.checkBit(addressBgAndWindowBitIndex) ? MMU.addressBgAndWindowArea1 : MMU.addressBgAndWindowArea2
        
        // Get Y coordinate relative to window or background space
        let relativeYCo = isRenderingWindow ? (currentScanline - windowY) : (currentScanline + scrollY)
        
        // Get row index of tile from row of 32 tiles
        let tileRowIndex = relativeYCo/8
        
        // Draw 160 horizontal pixels for scanline
        for pixelIndex in 0..<Self.pixelWidth {
            
            // Get X coordinate relative to window or background space
            // TODO: Confirm if this is correct. It seems that we can have a y-coordinate relative to the window
            // space, but an x-coordinate relative to the background space. That seems wrong.
            let isPixelIndexWithinWindowXBounds = pixelIndex >= windowX
            let shouldUseWindowSpaceForXCo = isRenderingWindow && isPixelIndexWithinWindowXBounds
            let relativeXCo = shouldUseWindowSpaceForXCo ? (pixelIndex - windowX) : (pixelIndex + scrollX)
            
            // Get column index of tile from column of 32 tiles
            let tileColumnIndex = relativeXCo/8
            
            // Get memory index of tile
            let tileIndexAddress: UInt16 = addressBgAndWindowArea
                + (UInt16(tileRowIndex) * Self.tilesPerRow)
                + UInt16(tileColumnIndex)
            let tileIndex = MMU.shared.readValue(address: tileIndexAddress)
            
            // Get memory address of tile
            let tileAddress: UInt16
            if isUsingTileDataAddress1 {
                // Tile Data Address 1 indexes using unsigned integer
                let tileAddressOffset = UInt16(tileIndex) * Self.bytesPerTile
                tileAddress = MMU.addressTileArea1 + tileAddressOffset
            } else {
                // Tile Data Address 2 indexes using signed integer
                let signedTileIndex = Int8(bitPattern: tileIndex)
                // Originates from UInt8 so guaranteed to be positive after adding 128
                let convertedTileIndex = Int16(signedTileIndex) + 128
                let tileAddressOffset = convertedTileIndex.magnitude * Self.bytesPerTile
                tileAddress = MMU.addressTileArea2 + tileAddressOffset
            }
            
            // Find which of the tile's pixel rows we are on and get the pixel row data from memory
            let pixelRowIndex = (relativeYCo % 8) * Self.bytesPerPixelRow
            let pixelRowAddress = tileAddress + UInt16(pixelRowIndex)
            let rowData1 = MMU.shared.readValue(address: pixelRowAddress)
            let rowData2 = MMU.shared.readValue(address: pixelRowAddress + 1)

            // Reverse pixel row data to align bit indices with pixel indices.
            // Pixel 0 corresponds to bit 7 of rowData1 and rowData2,
            // pixel 1 corresponds to bit 6 of rowData1 and rowData2,
            // etc.
            let reversedRowData1 = rowData1.reversedBits
            let reversedRowData2 = rowData2.reversedBits
            
            // Get the colour ID of the pixel
            let bitIndex = Int(relativeXCo % 8)
            let colourID = (reversedRowData2.getBitValue(bitIndex) << 1) | reversedRowData1.getBitValue(bitIndex)
            
            // Use colour ID to get colour from palette
            let palette = MMU.shared.readValue(address: MMU.addressBgPalette)
            let colour = ColourPalette.getColour(id: colourID, palette: palette)
            
            screenData[pixelIndex][currentScanline] = colour
        }
    }
    
    private func renderSprites() {
        
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
    
    // Miscellaneous
    private static let tilesPerRow: UInt16 = 32
    private static let windowXOffset: UInt8 = 7
}
