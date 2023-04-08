//
//  MMU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

class MMU {
    
    static let shared = MMU()
    
    var memoryMap: [UInt8]
    var rom: ROM?
    
    init() {
        memoryMap = Array(repeating: 0, count: Self.memorySizeBytes)
    }
    
    func loadRom(rom: ROM, skipBootRom: Bool) {
        memoryMap = Array(repeating: 0, count: Self.memorySizeBytes)
        self.rom = rom
        
        // First 16kB of memory map is fixed to first 16kB of ROM data.
        Self.fixedRomBankAddressRange.forEach { index in
            memoryMap[index] = rom.data[index]
        }
        
        // Second 16kB of memory map can be set and swapped between ROM banks.
        // The default is simply the second 16kB of ROM data.
        Self.switchableRomBankAddressRange.forEach { index in
            memoryMap[index] = rom.data[index]
        }
        
        // Overlay BIOS/BootRom at beginning
        memoryMap.replaceSubrange(0..<Self.bios.count, with: Self.bios)
        
        if skipBootRom {
            CPU.shared.skipBootRom()
            memoryMap[0xFF05] = 0x00
            memoryMap[0xFF06] = 0x00
            memoryMap[0xFF07] = 0x00
            memoryMap[0xFF10] = 0x80
            memoryMap[0xFF11] = 0xBF
            memoryMap[0xFF12] = 0xF3
            memoryMap[0xFF14] = 0xBF
            memoryMap[0xFF16] = 0x3F
            memoryMap[0xFF17] = 0x00
            memoryMap[0xFF19] = 0xBF
            memoryMap[0xFF1A] = 0x7F
            memoryMap[0xFF1B] = 0xFF
            memoryMap[0xFF1C] = 0x9F
            memoryMap[0xFF1E] = 0xBF
            memoryMap[0xFF20] = 0xFF
            memoryMap[0xFF21] = 0x00
            memoryMap[0xFF22] = 0x00
            memoryMap[0xFF23] = 0xBF
            memoryMap[0xFF24] = 0x77
            memoryMap[0xFF25] = 0xF3
            memoryMap[0xFF26] = 0xF1
            memoryMap[0xFF40] = 0x91
            memoryMap[0xFF42] = 0x00
            memoryMap[0xFF43] = 0x00
            memoryMap[0xFF45] = 0x00
            memoryMap[0xFF47] = 0xFC
            memoryMap[0xFF48] = 0xFF
            memoryMap[0xFF49] = 0xFF
            memoryMap[0xFF4A] = 0x00
            memoryMap[0xFF4B] = 0x00
            memoryMap[0xFFFF] = 0x00
        }
    }
    
    func readValue(address: UInt16) -> UInt8 {
        return memoryMap[address]
    }
    
    func writeValue(_ value: UInt8, address: UInt16) {
        let addressIsReadOnly = (address < 0x8000) || (0xFEA0...0xFEFF ~= address)
        guard !addressIsReadOnly else { return }
        
        switch address {
        case Self.readOnlyAddressRange:
            print("WARNING: Attempted to write to READ ONLY memory.")
            
        case Self.addressLY:
            // If the current scanline is attempted to be manually changed, set it to zero instead
            memoryMap[address] = 0
            
        case Self.addressDMATransferTrigger:
            dmaTransfer(byte: value)
            
        case Self.echoRamAddressRange:
            // Anything writted to this range (0xE000 - 0xFDFF) is also written to 0xC000-0xDDFF.
            memoryMap[address] = value
            writeValue(value, address: address - Self.echoRamOffset)
            
        case Self.probitedAddressRange:
            print("WARNING: Attempted to write to PROHIBITED memory.")
            
        case Self.addressDIV:
            // If anything tried to write to this, then it should instead just be reset.
            memoryMap[address] = 0
            
        default:
            // Standard write
            memoryMap[address] = value
        }
        
        // TODO: "When writing to DIV, the whole counter is reseted, so the timer is also affected."
        // REF: https://gbdev.gg8.se/wiki/articles/Timer_Obscure_Behaviour
    }
}

// MARK: - Interrupt Registers

extension MMU {
    
    private static let addressIE: UInt16 = 0xFFFF
    private static let addressIF: UInt16 = 0xFF0F
    
    private static let addressVBlankInterrupt: UInt16 = 0x0040
    private static let addressLcdInterrupt: UInt16 = 0x0048
    private static let addressTimerInterrupt: UInt16 = 0x0050
    private static let addressSerialInterrupt: UInt16 = 0x0058
    private static let addressJoypadInterrupt: UInt16 = 0x0060
    
    private static let vBlankInterruptBitIndex = 0
    private static let lcdInterruptBitIndex = 1
    private static let timerInterruptBitIndex = 2
    private static let serialInterruptBitIndex = 3
    private static let joypadInterruptBitIndex = 4
    
    func checkForInterrupt() -> UInt16? {
        let interruptByte = memoryMap[Self.addressIE] & memoryMap[Self.addressIF]
        
        // Priority is simply the bit order

        if interruptByte.checkBit(Self.vBlankInterruptBitIndex) {
            memoryMap[Self.addressIF].clearBit(Self.vBlankInterruptBitIndex)
            return Self.addressVBlankInterrupt
        }
        
        if interruptByte.checkBit(Self.lcdInterruptBitIndex) {
            memoryMap[Self.addressIF].clearBit(Self.lcdInterruptBitIndex)
            return Self.addressLcdInterrupt
        }
        
        if interruptByte.checkBit(Self.timerInterruptBitIndex) {
            memoryMap[Self.addressIF].clearBit(Self.timerInterruptBitIndex)
            return Self.addressTimerInterrupt
        }
        
        if interruptByte.checkBit(Self.serialInterruptBitIndex) {
            memoryMap[Self.addressIF].clearBit(Self.serialInterruptBitIndex)
            return Self.addressSerialInterrupt
        }

        if interruptByte.checkBit(Self.joypadInterruptBitIndex) {
            memoryMap[Self.addressIF].clearBit(Self.joypadInterruptBitIndex)
            return Self.addressJoypadInterrupt
        }
        
        return nil
    }
    
    func requestVBlankInterrupt() {
        memoryMap[Self.addressIF].setBit(Self.vBlankInterruptBitIndex)
    }
    
    func requestLCDInterrupt() {
        memoryMap[Self.addressIF].setBit(Self.lcdInterruptBitIndex)
    }
    
    func requestTimerInterrupt() {
        memoryMap[Self.addressIF].setBit(Self.timerInterruptBitIndex)
    }
    
    func requestSerialInterrupt() {
        memoryMap[Self.addressIF].setBit(Self.serialInterruptBitIndex)
    }
    
    func requestJoypadInterrupt() {
        memoryMap[Self.addressIF].setBit(Self.joypadInterruptBitIndex)
    }
}

// MARK: - Timer Registers

extension MMU {
    
    static let addressDIV: UInt16 = 0xFF04
    static let addressTIMA: UInt16 = 0xFF05
    static let addressTMA: UInt16 = 0xFF06
    static let addressTAC: UInt16 = 0xFF07
    
    static let timaEnabledBitIndex = 2
}

// MARK: - LCD Registers

extension MMU {
    
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
    
    // Use this instead of writing memory via writeValue(...) since that function
    // deliberately sets the scanline to 0 when any value is written to it.
    var currentScanline: UInt8 {
        get { memoryMap[Self.addressLY] }
        set { memoryMap[Self.addressLY] = newValue }
    }
    
    var isLCDEnabled: Bool {
        memoryMap[Self.addressLCDC].checkBit(Self.lcdAndPpuEnabledBitIndex)
    }
}

// MARK: - Tile And Sprite Data

extension MMU {
    
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
}

// MARK: - DMA Transfer

extension MMU {
    
    private static let addressDMATransferTrigger: UInt16 = 0xFF46 // Writing to this address launches a DMA transfer
    private static let dmaTransferSize: UInt16 = 0xA0
    private static let addressDMADestination: UInt16 = 0xFE00
    
    private func dmaTransfer(byte: UInt8) {
        let sourceAddress = UInt16(byte) << 8
        (0..<Self.dmaTransferSize).forEach { addressOffset in
            let value = readValue(address: sourceAddress + addressOffset)
            writeValue(value, address: Self.addressDMADestination + addressOffset)
        }
    }
}

// MARK: - Address Spaces

extension MMU {
    
    private static let memorySizeBytes = 64 * 1024 // 64KB
    
    private static let fixedRomBankAddressRange: ClosedRange<UInt16> = 0x0000...0x3FFF // Read-only
    private static let switchableRomBankAddressRange: ClosedRange<UInt16> = 0x4000...0x7FFF // Read-only
    private static let videoRamAddressRange: ClosedRange<UInt16> = 0x8000...0x9FFF
    private static let switchableRamBankAddressRange: ClosedRange<UInt16> = 0xA000...0xBFFF
    private static let internalRamAddressRange: ClosedRange<UInt16> = 0xC000...0xDFFF
    private static let echoRamAddressRange: ClosedRange<UInt16> = 0xE000...0xFDFF
    private static let spriteAttributesAddressRange: ClosedRange<UInt16> = 0xFE00...0xFE9F
    private static let probitedAddressRange: ClosedRange<UInt16> = 0xFEA0...0xFEFF // Prohibited
    private static let ioAddressRange: ClosedRange<UInt16> = 0xFF00...0xFF7F // or is the upper bound 0xFF4B?
    private static let highRamAddressRange: ClosedRange<UInt16> = 0xFF80...0xFFFE
    private static let interruptRegisterAddress: UInt16 = 0xFFFF // Duplicate, here for completeness.
    
    private static let readOnlyAddressRange: ClosedRange<UInt16> = 0x0000...0x7FFF
    private static let echoRamOffset: UInt16 = 0x2000
}

// MARK: - BIOS

extension MMU {
    
    // BootRom
    private static let bios: [UInt8] = [ // 256 Bytes long
        0x31, 0xFE, 0xFF, 0xAF, 0x21, 0xFF, 0x9F, 0x32, 0xCB, 0x7C, 0x20, 0xFB, 0x21, 0x26, 0xFF, 0x0E,
        0x11, 0x3E, 0x80, 0x32, 0xE2, 0x0C, 0x3E, 0xF3, 0xE2, 0x32, 0x3E, 0x77, 0x77, 0x3E, 0xFC, 0xE0,
        0x47, 0x11, 0x04, 0x01, 0x21, 0x10, 0x80, 0x1A, 0xCD, 0x95, 0x00, 0xCD, 0x96, 0x00, 0x13, 0x7B,
        0xFE, 0x34, 0x20, 0xF3, 0x11, 0xD8, 0x00, 0x06, 0x08, 0x1A, 0x13, 0x22, 0x23, 0x05, 0x20, 0xF9,
        0x3E, 0x19, 0xEA, 0x10, 0x99, 0x21, 0x2F, 0x99, 0x0E, 0x0C, 0x3D, 0x28, 0x08, 0x32, 0x0D, 0x20,
        0xF9, 0x2E, 0x0F, 0x18, 0xF3, 0x67, 0x3E, 0x64, 0x57, 0xE0, 0x42, 0x3E, 0x91, 0xE0, 0x40, 0x04,
        0x1E, 0x02, 0x0E, 0x0C, 0xF0, 0x44, 0xFE, 0x90, 0x20, 0xFA, 0x0D, 0x20, 0xF7, 0x1D, 0x20, 0xF2,
        0x0E, 0x13, 0x24, 0x7C, 0x1E, 0x83, 0xFE, 0x62, 0x28, 0x06, 0x1E, 0xC1, 0xFE, 0x64, 0x20, 0x06,
        0x7B, 0xE2, 0x0C, 0x3E, 0x87, 0xF2, 0xF0, 0x42, 0x90, 0xE0, 0x42, 0x15, 0x20, 0xD2, 0x05, 0x20,
        0x4F, 0x16, 0x20, 0x18, 0xCB, 0x4F, 0x06, 0x04, 0xC5, 0xCB, 0x11, 0x17, 0xC1, 0xCB, 0x11, 0x17,
        0x05, 0x20, 0xF5, 0x22, 0x23, 0x22, 0x23, 0xC9, 0xCE, 0xED, 0x66, 0x66, 0xCC, 0x0D, 0x00, 0x0B,
        0x03, 0x73, 0x00, 0x83, 0x00, 0x0C, 0x00, 0x0D, 0x00, 0x08, 0x11, 0x1F, 0x88, 0x89, 0x00, 0x0E,
        0xDC, 0xCC, 0x6E, 0xE6, 0xDD, 0xDD, 0xD9, 0x99, 0xBB, 0xBB, 0x67, 0x63, 0x6E, 0x0E, 0xEC, 0xCC,
        0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E, 0x3c, 0x42, 0xB9, 0xA5, 0xB9, 0xA5, 0x42, 0x3C,
        0x21, 0x04, 0x01, 0x11, 0xA8, 0x00, 0x1A, 0x13, 0xBE, 0x20, 0xFE, 0x23, 0x7D, 0xFE, 0x34, 0x20,
        0xF5, 0x06, 0x19, 0x78, 0x86, 0x23, 0x05, 0x20, 0xFB, 0x86, 0x20, 0xFE, 0x3E, 0x01, 0xE0, 0x50
    ]
}
