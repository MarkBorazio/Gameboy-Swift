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
    var cartridge: Cartridge?
    var isBootRomOverlayed = false
    
    init() {
        memoryMap = Array(repeating: 0, count: Memory.memorySizeBytes)
    }
    
    func loadCartridge(cartridge: Cartridge, skipBootRom: Bool) {
        memoryMap = Array(repeating: 0, count: Memory.memorySizeBytes)
        self.cartridge = cartridge
        
        if skipBootRom {
            CPU.shared.skipBootRom()
            memoryMap[Memory.addressTIMA] = 0x00
            memoryMap[Memory.addressTMA] = 0x00
            memoryMap[Memory.addressTAC] = 0x00
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
            memoryMap[Memory.addressLCDC] = 0x91
            memoryMap[Memory.addressScrollY] = 0x00
            memoryMap[Memory.addressScrollX] = 0x00
            memoryMap[Memory.addressLYC] = 0x00
            memoryMap[Memory.addressBgPalette] = 0xFC
            memoryMap[Memory.addressObjPalette1] = 0xFF
            memoryMap[Memory.addressObjPalette2] = 0xFF
            memoryMap[Memory.addressWindowY] = 0x00
            memoryMap[Memory.addressWindowX] = 0x00
            memoryMap[Memory.interruptRegisterAddress] = 0x00
        } else {
            // Overlay BIOS/BootRom at beginning
            memoryMap.replaceSubrange(Self.biosAddressRange, with: Self.bios)
            isBootRomOverlayed = true
        }
    }
    
    private func removeBootRomOverlay() {
        isBootRomOverlayed = false
    }
    
    func readValue(address: UInt16) -> UInt8 {
        switch address {
        case Memory.addressJoypad:
            return Joypad.shared.readJoypad()
        case Memory.fixedRomBankAddressRange,
            Memory.switchableRomBankAddressRange,
            Memory.switchableRamBankAddressRange:
            return cartridge!.read(address: address) // TODO: Fixo.
        default:
            return memoryMap[address]
        }
    }
    
    func writeValue(_ value: UInt8, address: UInt16) {
        
        switch address {
            
        case Memory.ramEnableAddressRange,
            Memory.setBankRegister1AddressRange,
            Memory.setBankRegister2AddressRange,
            Memory.switchableRamBankAddressRange,
            Memory.setBankModeAddressRange:
            cartridge?.write(value, address: address)
            return
            
        case Memory.biosDeactivateAddress:
            if value == 1 {
                isBootRomOverlayed = false
            }
            memoryMap[address] = value
            
        case Memory.addressLY:
            // If the current scanline is attempted to be manually changed, set it to zero instead
            memoryMap[address] = 0
            
        case Memory.addressDMATransferTrigger:
            dmaTransfer(byte: value)
            
        case Memory.echoRamAddressRange:
            // Anything writted to this range (0xE000 - 0xFDFF) is also written to 0xC000-0xDDFF.
            memoryMap[address] = value
            writeValue(value, address: address - Memory.echoRamOffset)
            
        case Memory.addressDIV:
            // If anything tries to write to this, then it should instead just be reset.
            memoryMap[address] = 0
            
        case Memory.addressTAC:
            // If we change the clock frequency, we need to reset it.
            let previousFrequency = MasterClock.shared.clockCyclesPerTimaCycle
            memoryMap[address] = value
            let newFrequency = MasterClock.shared.clockCyclesPerTimaCycle
            if previousFrequency != newFrequency {
                MasterClock.shared.resetTimaCycle()
            }
            
        case Memory.probitedAddressRange:
            return
            
        default:
            // Standard write
            memoryMap[address] = value
        }
        
        // TODO: "When writing to DIV, the whole counter is reseted, so the timer is also affected."
        // REF: https://gbdev.gg8.se/wiki/articles/Timer_Obscure_Behaviour
    }
}

// MARK: - Interrupts

extension MMU {
    
    var hasPendingAndEnabledInterrupt: Bool {
        let interruptByte = memoryMap[Memory.addressIE] & memoryMap[Memory.addressIF]
        return interruptByte & 0b0001_1111 != 0 // First five bits correspond to pending interrupts as per static definitions above
    }
    
    func getNextPendingAndEnabledInterrupt() -> UInt16? {
        var interruptFlags = memoryMap[Memory.addressIF]
        let interuptEnable = memoryMap[Memory.addressIE]
        let interruptByte = interuptEnable & interruptFlags
        
        // Priority is simply the bit order

        if interruptByte.checkBit(Memory.vBlankInterruptBitIndex) {
            interruptFlags.clearBit(Memory.vBlankInterruptBitIndex)
            memoryMap[Memory.addressIF] = interruptFlags
            return Memory.addressVBlankInterrupt
        }
        
        if interruptByte.checkBit(Memory.lcdInterruptBitIndex) {
            interruptFlags.clearBit(Memory.lcdInterruptBitIndex)
            memoryMap[Memory.addressIF] = interruptFlags
            return Memory.addressLcdInterrupt
        }
        
        if interruptByte.checkBit(Memory.timerInterruptBitIndex) {
            interruptFlags.clearBit(Memory.timerInterruptBitIndex)
            memoryMap[Memory.addressIF] = interruptFlags
            return Memory.addressTimerInterrupt
        }
        
        if interruptByte.checkBit(Memory.serialInterruptBitIndex) {
            interruptFlags.clearBit(Memory.serialInterruptBitIndex)
            memoryMap[Memory.addressIF] = interruptFlags
            return Memory.addressSerialInterrupt
        }

        if interruptByte.checkBit(Memory.joypadInterruptBitIndex) {
            interruptFlags.clearBit(Memory.joypadInterruptBitIndex)
            memoryMap[Memory.addressIF] = interruptFlags
            return Memory.addressJoypadInterrupt
        }
        
        return nil
    }
    
    func requestVBlankInterrupt() {
        var interruptFlags = memoryMap[Memory.addressIF]
        interruptFlags.setBit(Memory.vBlankInterruptBitIndex)
        memoryMap[Memory.addressIF] = interruptFlags
    }
    
    func requestLCDInterrupt() {
        var interruptFlags = memoryMap[Memory.addressIF]
        interruptFlags.setBit(Memory.lcdInterruptBitIndex)
        memoryMap[Memory.addressIF] = interruptFlags
    }
    
    func requestTimerInterrupt() {
        var interruptFlags = memoryMap[Memory.addressIF]
        interruptFlags.setBit(Memory.timerInterruptBitIndex)
        memoryMap[Memory.addressIF] = interruptFlags
    }
    
    func requestSerialInterrupt() {
        var interruptFlags = memoryMap[Memory.addressIF]
        interruptFlags.setBit(Memory.serialInterruptBitIndex)
        memoryMap[Memory.addressIF] = interruptFlags
    }
    
    func requestJoypadInterrupt() {
        var interruptFlags = memoryMap[Memory.addressIF]
        interruptFlags.setBit(Memory.joypadInterruptBitIndex)
        memoryMap[Memory.addressIF] = interruptFlags
    }
}

// MARK: - LCD Registers

extension MMU {
    
    func getScanline() -> UInt8 {
        memoryMap[Memory.addressLY]
    }
    
    // Use this instead of writing memory via writeValue(...) since that function
    // deliberately sets the scanline to 0 when any value is written to it.
    func setScanline(_ value: UInt8) {
        memoryMap[Memory.addressLY] = value
    }
    
    var isLCDEnabled: Bool {
        let lcdc = memoryMap[Memory.addressLCDC]
        return lcdc.checkBit(Memory.lcdAndPpuEnabledBitIndex)
    }
}

// MARK: - DMA Transfer

extension MMU {
    
    private func dmaTransfer(byte: UInt8) {
        let sourceAddress = UInt16(byte) << 8
        (0..<Memory.dmaTransferSize).forEach { addressOffset in
            let value = readValue(address: sourceAddress + addressOffset)
            writeValue(value, address: Memory.addressDMADestination + addressOffset)
        }
    }
}

// MARK: - BIOS

extension MMU {
    
    private static let biosAddressRange: Range<Int> = 0..<bios.count
    
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
