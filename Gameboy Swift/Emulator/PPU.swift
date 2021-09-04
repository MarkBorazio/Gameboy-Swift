//
//  PPU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 28/8/21.
//

import Foundation

class PPU {
    
    static let shared = PPU()
    
    private static let machineCyclesPerScanline = 114 // 456 clock cycles
    private var scanlineTimer = 0
    
    func update(machineCycles: Int) {
        updateLCDStatus()
        guard MMU.shared.isLCDEnabled else { return }
        
        scanlineTimer += machineCycles
        if scanlineTimer >= Self.machineCyclesPerScanline {
            scanlineTimer = 0
            
            MMU.shared.currentScanline += 1
            let currentScanlineIndex = MMU.shared.currentScanline
            
            if currentScanlineIndex <= Self.lastScanlineIndex { // Draw visible scanline
                drawScanline()
            }
            else if currentScanlineIndex == (Self.lastVisibleScanlineIndex + 1) { // Entered VBlank period
                MMU.shared.requestVBlankInterrupt()
            }
            else if currentScanlineIndex > Self.lastScanlineIndex { // Reset
                MMU.shared.currentScanline = 0
            }
        }
    }
    
    private func updateLCDStatus() {
        var status = MMU.shared.readValue(address: MMU.addressLCDS)
        
        if !MMU.shared.isLCDEnabled {
            // LCD is disabled, so reset scanline and set mode to vBlank.
            scanlineTimer = 0
            MMU.shared.currentScanline = 0
            
            status &= ~Self.lcdModeMask
            status |= Self.vBlankMode
        } else {
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
                if Self.searchingOAMScanlineIndexBounds ~= currentScanlineIndex {
                    newLCDMode = Self.searchingOAMMode
                    status &= ~Self.lcdModeMask
                    status |= Self.searchingOAMMode
                    interruptRequired = status.checkBit(MMU.searchingOAMBitIndex)
                } else if Self.transferringDataToLCDScanlineIndexBounds ~= currentScanlineIndex {
                    newLCDMode = Self.transferringDataToLCDMode
                    status &= ~Self.lcdModeMask
                    status |= Self.transferringDataToLCDMode
                    interruptRequired = false
                } else {
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
        }
        
        MMU.shared.writeValue(status, address: MMU.addressLCDS)
    }
    
    private func drawScanline() {
        
    }
}

// MARK: - Constants

extension PPU {
    
    // Scanlines
    private static let lastVisibleScanlineIndex: UInt8 = 143
    private static let lastScanlineIndex: UInt8 = 153
    private static let searchingOAMScanlineIndexBounds: ClosedRange<UInt8> = 0...79 // First 80 scanlines
    private static let transferringDataToLCDScanlineIndexBounds: ClosedRange<UInt8> = 80...251 // Next 172 scanlines
    
    // LCD Modes
    private static let lcdModeMask: UInt8 = 0b00000011
    private static let hBlankMode: UInt8 = 0b00
    private static let vBlankMode: UInt8 = 0b01
    private static let searchingOAMMode: UInt8 = 0b10
    private static let transferringDataToLCDMode: UInt8 = 0b11
}
