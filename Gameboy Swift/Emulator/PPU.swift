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
        
        guard isLCDEnabled() else { return }
        
        scanlineTimer += machineCycles
        if scanlineTimer >= Self.machineCyclesPerScanline {
            scanlineTimer = 0
            
            MMU.shared.currentScanline += 1
            let currentScanline = MMU.shared.currentScanline
            
            if currentScanline == 144 {
                MMU.shared.requestVBlankInterrupt()
            }
            else if currentScanline >= 154 {
                // At last scanline.
                MMU.shared.currentScanline = 0
            }
            else {
                drawScanline()
            }
        }
    }
    
    private func updateLCDStatus() {
        
    }
    
    // TODO: This.
    private func isLCDEnabled() -> Bool {
        return true
    }
    
    private func drawScanline() {
        
    }
}
