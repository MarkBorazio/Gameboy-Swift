//
//  PPU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 28/8/21.
//

import Foundation

class PPU {
    
    static let shared = PPU()
    
    private var scanlineTimer = 0
    
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
        let control = MMU.shared.readValue(address: MMU.addressLCDC)
        let bgAndWindowTileDataAreaFlag = control.checkBit(MMU.bgAndWindowTileDataAreaBitIndex)
        
        if bgAndWindowTileDataAreaFlag {
            
        } else {
            
        }
    }
    
    private func renderSprites() {
        
    }
}

// MARK: - Constants

extension PPU {
    
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
    private static let 
}
