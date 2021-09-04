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
    
    func loadRom(rom: ROM) {
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
    }
    
    func readValue(address: UInt16) -> UInt8 {
        return memoryMap[address]
    }
    
    func writeValue(_ value: UInt8, address: UInt16) {
        let addressIsReadOnly = (address < 0x8000) || (0xFEA0...0xFEFF ~= address)
        guard !addressIsReadOnly else { return }
        
        if address == Self.addressLY {
            // If the current scanline is attempted to be manually changed, set it to zero instead.
            memoryMap[address] = 0
        } else {
            // Standard write.
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
}

// MARK: - Timer Registers

extension MMU {
    
    private static let addressDIV: UInt16 = 0xFF04
    private static let addressTIMA: UInt16 = 0xFF05
    private static let addressTMA: UInt16 = 0xFF06
    private static let addressTAC: UInt16 = 0xFF07
    
    func incrementDivRegister() {
        memoryMap[Self.addressDIV] &+= 1
    }
    
    // This thing is pretty complicated: https://gbdev.gg8.se/wiki/articles/Timer_Obscure_Behaviour
    // TODO: The rest of the complexity.
    func incrementTimaRegister() {
        // Make sure timer is enabled first
        guard memoryMap[Self.addressTAC].checkBit(2) else { return }
        
        let oldValue = memoryMap[Self.addressTIMA]
        let (newValue, overflow) = oldValue.addingReportingOverflow(1)
        memoryMap[Self.addressTIMA] = newValue
        
        if overflow {
            // TODO: The following actually needs to be done after 1 cycle from this point.
            memoryMap[Self.addressTIMA] = memoryMap[Self.addressTMA]
            memoryMap[Self.addressIF].setBit(Self.timerInterruptBitIndex) // Request Interrupt
        }
    }
    
    var clockCyclesPerTimaCycle: UInt32 {
        let rawValue = memoryMap[Self.addressTAC] & 0b11
        switch rawValue {
        case 0b00: return 1024 // 4096 Hz
        case 0b01: return 16 // 262144 Hz
        case 0b10: return 64 // 65536 Hz
        case 0b11: return 256 // 16384 Hz
        default: fatalError("This should never be reached.")
        }
    }
}

// MARK: - LCD Registers

extension MMU {
    
    private static let addressLCDC: UInt16 = 0xFF40 // LCD Control
    static let addressLCDS: UInt16 = 0xFF41 // LCD Status
    static let addressLY: UInt16 = 0xFF44 // Current Scanline
    static let addressLYC: UInt16 = 0xFF45
    
    // LCDC Bit Indices
    private static let bgAndWindowEnabledBitIndex = 0
    private static let objectsEnabledBitIndex = 1
    private static let objectSizeBitIndex = 2
    private static let bgTileMapAreaBitIndex = 3
    private static let bgAndWindowTileDataAreaBitIndex = 4
    private static let windowEnabledBitIndex = 5
    private static let windowTileMapAreaBitIndex = 6
    private static let lcdAndPpuEnabledBitIndex = 7
    
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

// MARK: - Address Spaces

extension MMU {
    
    private static let memorySizeBytes = 64 * 1024 // 64KB
    
    private static let fixedRomBankAddressRange: ClosedRange<UInt16> = 0x0000...0x3FFF
    private static let switchableRomBankAddressRange: ClosedRange<UInt16> = 0x4000...0x7FFF
    private static let videoRamAddressRange: ClosedRange<UInt16> = 0x8000...0x9FFF
    private static let switchableRamBankAddressRange: ClosedRange<UInt16> = 0xA000...0xBFFF
    private static let internalRamAddressRange: ClosedRange<UInt16> = 0xC000...0xDFFF
    private static let spriteAttributesAddressRange: ClosedRange<UInt16> = 0xFE00...0xFE9F
    private static let ioAddressRange: ClosedRange<UInt16> = 0xFF00...0xFF4B
    private static let highRamAddressRange: ClosedRange<UInt16> = 0xFF80...0xFFFE
    private static let interruptRegisterAddress: UInt16 = 0xFFFF // Duplicate, here for completeness.
}

// MARK: - BIOS

extension MMU {
    
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
        0xDD, 0xDC, 0x99, 0x9F, 0xBB, 0xB9, 0x33, 0x3E, 0x3c, 0x42, 0xB9, 0xA5, 0xB9, 0xA5, 0x42, 0x4C,
        0x21, 0x04, 0x01, 0x11, 0xA8, 0x00, 0x1A, 0x13, 0xBE, 0x20, 0xFE, 0x23, 0x7D, 0xFE, 0x34, 0x20,
        0xF5, 0x06, 0x19, 0x78, 0x86, 0x23, 0x05, 0x20, 0xFB, 0x86, 0x20, 0xFE, 0x3E, 0x01, 0xE0, 0x50
    ]
}
