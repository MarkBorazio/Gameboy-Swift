//
//  Memory.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 12/4/2023.
//

import Foundation

// Static definitions for addresses and bit indices
enum Memory {
    
    static let memorySizeBytes = 64 * 1024 // 64KB
    
    
    // MARK: - Address Spaces
    
    static let fixedRomBankAddressRange: ClosedRange<UInt16> = 0x0000...0x3FFF // Read-only
    static let switchableRomBankAddressRange: ClosedRange<UInt16> = 0x4000...0x7FFF // Read-only
    static let videoRamAddressRange: ClosedRange<UInt16> = 0x8000...0x9FFF
    static let switchableRamBankAddressRange: ClosedRange<UInt16> = 0xA000...0xBFFF
    static let internalRamAddressRange: ClosedRange<UInt16> = 0xC000...0xDFFF
    static let echoRamAddressRange: ClosedRange<UInt16> = 0xE000...0xFDFF
    static let spriteAttributesAddressRange: ClosedRange<UInt16> = 0xFE00...0xFE9F
    static let probitedAddressRange: ClosedRange<UInt16> = 0xFEA0...0xFEFF // Prohibited
    static let ioAddressRange: ClosedRange<UInt16> = 0xFF00...0xFF7F // or is the upper bound 0xFF4B?
    static let highRamAddressRange: ClosedRange<UInt16> = 0xFF80...0xFFFE
    static let interruptRegisterAddress: UInt16 = 0xFFFF // Duplicate, here for completeness.
    
    static let readOnlyAddressRange: ClosedRange<UInt16> = 0x0000...0x7FFF
    static let echoRamOffset: UInt16 = 0x2000
    
    
    // MARK: - Cartridge
    
    static let headerAddressRange: ClosedRange<UInt16> = 0x0100...0x014F
    static let cartridgeTypeAddress: UInt16 = 0x0147
    static let ramBanksAddress: UInt16 = 0x0148
    
    
    // MARK: - Interrupts
    
    static let addressIE: UInt16 = 0xFFFF
    static let addressIF: UInt16 = 0xFF0F
    
    static let addressVBlankInterrupt: UInt16 = 0x0040
    static let addressLcdInterrupt: UInt16 = 0x0048
    static let addressTimerInterrupt: UInt16 = 0x0050
    static let addressSerialInterrupt: UInt16 = 0x0058
    static let addressJoypadInterrupt: UInt16 = 0x0060
    
    static let vBlankInterruptBitIndex = 0
    static let lcdInterruptBitIndex = 1
    static let timerInterruptBitIndex = 2
    static let serialInterruptBitIndex = 3
    static let joypadInterruptBitIndex = 4
    
    
    // MARK: - Joypad
    
    static let addressJoypad: UInt16 = 0xFF00
    
    static let selectActionButtonsBitIndex = 5
    static let selectDirectionButtonsBitIndex = 4
    static let joypadDownOrStartBitIndex = 3
    static let joypadUpOrSelectBitIndex = 2
    static let joypadLeftOrBBitIndex = 1
    static let joypadRightOrABitIndex = 0
    
    
    // MARK: - Timers
    
    static let addressDIV: UInt16 = 0xFF04
    static let addressTIMA: UInt16 = 0xFF05
    static let addressTMA: UInt16 = 0xFF06
    static let addressTAC: UInt16 = 0xFF07
    
    static let timaEnabledBitIndex = 2
    
    
    // MARK: - LCD Registers
    
    static let addressLCDC: UInt16 = 0xFF40 // LCD Control
    static let addressLCDS: UInt16 = 0xFF41 // LCD Status
    static let addressLY: UInt16 = 0xFF44 // Current Scanline
    static let addressBgPalette: UInt16 = 0xFF47 // Background Colour Palette
    static let addressObjPalette1: UInt16 = 0xFF48 // Object Colour Palette 1
    static let addressObjPalette2: UInt16 = 0xFF49 // Object Colour Palette 2
    static let addressLYC: UInt16 = 0xFF45
    
    // LCDC Bit Indices
    static let bgAndWindowEnabledBitIndex = 0
    static let objectsEnabledBitIndex = 1
    static let objectSizeBitIndex = 2
    static let bgTileMapAreaBitIndex = 3
    static let bgAndWindowTileDataAreaBitIndex = 4
    static let windowEnabledBitIndex = 5
    static let windowTileMapAreaBitIndex = 6
    static let lcdAndPpuEnabledBitIndex = 7
    
    // LCDS Bit Indices
    static let coincidenceBitIndex = 2
    static let hBlankInterruptEnabledBitIndex = 3
    static let vBlankInterruptEnabledBitIndex = 4
    static let searchingOAMBitIndex = 5
    static let coincidenceInterruptEnabledBitIndex = 6
    
    
    // MARK: - Tile And Sprite Data
    
    static let addressTileArea1: UInt16 = 0x8000
    static let addressTileArea2: UInt16 = 0x8800
    static let addressBgAndWindowArea1: UInt16 = 0x9C00
    static let addressBgAndWindowArea2: UInt16 = 0x9800
    static let addressScrollY: UInt16 = 0xFF42
    static let addressScrollX: UInt16 = 0xFF43
    static let addressWindowY: UInt16 = 0xFF4A
    static let addressWindowX: UInt16 = 0xFF4B
    static let addressOAM: UInt16 = 0xFE00
    
    // Sprite Attributes Bit Indices
    // Bits 0-3 are used in CGB mode only
    static let paletteNumberBitIndex = 4
    static let xFlipBitIndex = 5
    static let yFlipBitIndex = 6
    static let bgAndWindowOverObjBitIndex = 7
    
    
    // MARK: - DMA Transfer
    
    static let addressDMATransferTrigger: UInt16 = 0xFF46 // Writing to this address launches a DMA transfer
    static let dmaTransferSize: UInt16 = 0xA0
    static let addressDMADestination: UInt16 = 0xFE00
    
    
    // MARK: - BIOS
    
    // Writing a value of `0x1` to the address 0xFF50 removes the bootrom/bios overlay
    // and puts the orginial rom data back.
    static let biosDeactivateAddress: UInt16 = 0xFF50
    static let biosDeactivateValue: UInt8 = 0x1
}