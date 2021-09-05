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
            count: Int(pixelsPerColumn)
        ),
        count: Int(pixelsPerRow)
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
        
        if control.checkBit(MMU.bgAndWindowEnabledBitIndex) {
            renderTiles()
        }
        
        if control.checkBit(MMU.objectsEnabledBitIndex) {
            renderSprites()
        }
    }
    
    private func renderTiles() {
        var tileData: UInt16 = 0
        var backgroundMemory: UInt16 = 0
        var unsigned = true
        
        let scrollY = MMU.shared.readValue(address: MMU.addressScrollY)
        let scrollX = MMU.shared.readValue(address: MMU.addressScrollX)
        let windowY = MMU.shared.readValue(address: MMU.addressWindowY)
        let windowX = MMU.shared.readValue(address: MMU.addressWindowX) - Self.windowXOffset
        
        var usingWindow = false
        
        let control = MMU.shared.readValue(address: MMU.addressLCDC)
        
        // Check if window is enabled
        if control.checkBit(MMU.windowEnabledBitIndex) {
            // Check if scanline is within windows position
            if windowY <= MMU.shared.currentScanline {
                usingWindow = true
            }
        }
        
        // Figure out which area of tile data we want to use
        if control.checkBit(MMU.bgAndWindowTileDataAreaBitIndex) {
            tileData = MMU.addressTileArea1
        } else {
            tileData = MMU.addressTileArea2
            unsigned = false
        }
        
        // Figure out which are of background memory to use
        if !usingWindow {
            if control.checkBit(MMU.bgTileMapAreaBitIndex) {
                backgroundMemory = MMU.addressBgAndWindowArea1
            } else {
                backgroundMemory = MMU.addressBgAndWindowArea2
            }
        } else {
            if control.checkBit(MMU.windowTileMapAreaBitIndex) {
                backgroundMemory = MMU.addressBgAndWindowArea1
            } else {
                backgroundMemory = MMU.addressBgAndWindowArea2
            }
        }
        
        var yPos: UInt8 = 0
        // Calculate y position of scanline
        if !usingWindow {
            yPos = scrollY + MMU.shared.currentScanline
        } else {
            yPos = MMU.shared.currentScanline - windowY
        }
        
        // Figure out which of the 8 pixel rows of current tile the scanline is on
        let tileRow: UInt8 = (yPos/8) * 32 // ???
        
        // Draw 160 horizontal pixels for scanline
        for pixelIndex in 0..<Self.pixelsPerRow {
            var xPos = pixelIndex + scrollX
            
            // Translate x position to window space if required
            if usingWindow {
                if pixelIndex >= windowX {
                    xPos = pixelIndex - windowX
                }
            }
            
            // Figure out which of 32 horizontal tiles in row the x position is within
            let tileCol: UInt16 = UInt16(xPos)/8
            let tileNum: Int16
            
            // Get tile ID (can be signed or unsigned)
            let tileAddress = backgroundMemory + UInt16(tileRow) + tileCol
            if unsigned {
                let rawTileNum = UInt16(MMU.shared.readValue(address: tileAddress))
                tileNum = Int16(bitPattern: rawTileNum)
            } else {
                let rawTileNum = Int8(bitPattern: MMU.shared.readValue(address: tileAddress))
                tileNum = Int16(rawTileNum)
            }
            
            // Figure out where the tile identifier is in memory
            var tileLocation = tileData
            if unsigned {
                tileLocation += tileNum.magnitude * Self.bytesPerTile
            } else {
                tileLocation += UInt16((tileNum + 128) * Int16(Self.bytesPerTile))
            }
            
            // Find which of the tile's pixel rows we are on to get pixel row data from memory
            let rawLine = (yPos % 8) * Self.bytesPerTileRow
            let line = UInt16(rawLine)
            let rowData1 = MMU.shared.readValue(address: tileLocation + line)
            let rowData2 = MMU.shared.readValue(address: tileLocation + line + 1)
            
            // Pixel 0 corresponds to bit 7 of rowData1 and rowData2,
            // pixel 1 corresponds to bit 6 of rowData1 and rowData2,
            // etc.
            var colourBit = Int(xPos % 8)
            colourBit -= 7
            colourBit *= -1
            
            // Get two bit colour ID
            var colourNum = rowData2.getBitValue(colourBit)
            colourNum <<= 1
            colourNum |= rowData1.getBitValue(colourBit)
            
            // Use colour ID to get colour from palette
            let palette = MMU.shared.readValue(address: MMU.addressBgPalette)
            let colour = ColourPalette.getColour(id: colourNum, byte: palette)
            
            // Safety check to make sure we are within bounds
            let finally = MMU.shared.currentScanline
            if finally < 0 || finally > 143 || pixelIndex < 0 || pixelIndex > 159 {
                continue
            }
            
            screenData[pixelIndex][finally] = colour
        }
    }
    
    private func renderSprites() {
        
    }
}

// MARK: - Constants

extension PPU {
    
    // Resolution
    private static let pixelsPerRow: UInt8 = 160
    private static let pixelsPerColumn: UInt8 = 144
    
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
    private static let bytesPerTileRow: UInt8 = 2
    
    // Miscellaneous
    private static let windowXOffset: UInt8 = 7
}
