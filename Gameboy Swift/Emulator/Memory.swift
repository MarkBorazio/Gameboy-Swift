//
//  Memory.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

class Memory {
    
    var memoryMap: [UInt8]
    var rom: ROM?
    
    init() {
        memoryMap = Array(repeating: 0, count: Self.memorySizeBytes)
    }
    
    func loadRom(rom: ROM) {
        memoryMap = Array(repeating: 0, count: Self.memorySizeBytes)
        self.rom = rom
        
        // First 16kB of memory map is fixed to first 16kB of ROM data.
        Self.fixedRomBankAddressRange.forEach { index in
            memoryMap[index] = rom.data[index]
        }
        
        // Second 16kB of memory map can be set and swapped between ROM banks.
        // We simply initialise it with the second 16kB of ROM data.
        Self.switchableRomBankAddressRange.forEach { index in
            memoryMap[index] = rom.data[index]
        }
    }
    
    func readOpcode(address: UInt16) -> UInt8 {
        return memoryMap[address]
    }
}

// MARK: - Constants

extension Memory {
    
    private static let memorySizeBytes = 64 * 1024 // 64KB
    
    // Address Ranges
    private static let fixedRomBankAddressRange: ClosedRange<UInt16> = 0x0000...0x3FFF
    private static let switchableRomBankAddressRange: ClosedRange<UInt16> = 0x4000...0x7FFF
    private static let videoRamAddressRange: ClosedRange<UInt16> = 0x8000...0x9FFF
    private static let switchableRamBankAddressRange: ClosedRange<UInt16> = 0xA000...0xBFFF
    private static let internalRamAddressRange: ClosedRange<UInt16> = 0xC000...0xDFFF
    private static let spriteAttributesAddressRange: ClosedRange<UInt16> = 0xFE00...0xFE9F
    private static let ioAddressRange: ClosedRange<UInt16> = 0xFF00...0xFF4B
    private static let highRamAddressRange: ClosedRange<UInt16> = 0xFF80...0xFFFE
    private static let interruptRegisterAddress: UInt16 = 0xFFFF
}
