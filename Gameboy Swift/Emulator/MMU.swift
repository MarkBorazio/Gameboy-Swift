//
//  MMU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

class MMU {
    
    static let shared = MMU()
    
    private var memoryMap: [UInt8]
    private var cartridge: Cartridge?
    private var isBootRomOverlayed = false
    
    init() {
        memoryMap = Array(repeating: 0, count: Memory.internalMemorySize)
    }
    
    func loadCartridge(cartridge: Cartridge, skipBootRom: Bool) {
        memoryMap = Array(repeating: 0, count: Memory.internalMemorySize)
        self.cartridge = cartridge
        
        if skipBootRom {
            CPU.shared.skipBootRom()
            safeWriteValue(0x00, globalAddress: Memory.addressTIMA)
            safeWriteValue(0x00, globalAddress: Memory.addressTMA)
            safeWriteValue(0x00, globalAddress: Memory.addressTAC)
            safeWriteValue(0x80, globalAddress: Memory.addressNR10)
            safeWriteValue(0xBF, globalAddress: Memory.addressNR11)
            safeWriteValue(0xF3, globalAddress: Memory.addressNR12)
            safeWriteValue(0xBF, globalAddress: Memory.addressNR14)
            safeWriteValue(0x3F, globalAddress: Memory.addressNR21)
            safeWriteValue(0x00, globalAddress: Memory.addressNR22)
            safeWriteValue(0xBF, globalAddress: Memory.addressNR24)
            safeWriteValue(0x7F, globalAddress: Memory.addressNR30)
            safeWriteValue(0xFF, globalAddress: Memory.addressNR31)
            safeWriteValue(0x9F, globalAddress: Memory.addressNR32)
            safeWriteValue(0xBF, globalAddress: Memory.addressNR34)
            safeWriteValue(0xFF, globalAddress: Memory.addressNR41)
            safeWriteValue(0x00, globalAddress: Memory.addressNR42)
            safeWriteValue(0x00, globalAddress: Memory.addressNR43)
            safeWriteValue(0xBF, globalAddress: Memory.addressNR44)
            safeWriteValue(0x77, globalAddress: Memory.addressNR50)
            safeWriteValue(0xF3, globalAddress: Memory.addressNR51)
            safeWriteValue(0xF1, globalAddress: Memory.addressNR52)
            safeWriteValue(0x91, globalAddress: Memory.addressLCDC)
            safeWriteValue(0x00, globalAddress: Memory.addressScrollY)
            safeWriteValue(0x00, globalAddress: Memory.addressScrollX)
            safeWriteValue(0x00, globalAddress: Memory.addressLYC)
            safeWriteValue(0xFC, globalAddress: Memory.addressBgPalette)
            safeWriteValue(0xFF, globalAddress: Memory.addressObjPalette1)
            safeWriteValue(0xFF, globalAddress: Memory.addressObjPalette2)
            safeWriteValue(0x00, globalAddress: Memory.addressWindowY)
            safeWriteValue(0x00, globalAddress: Memory.addressWindowX)
            safeWriteValue(0x00, globalAddress: Memory.interruptRegisterAddress)
        } else {
            isBootRomOverlayed = true
        }
    }
    
    func safeReadValue(globalAddress: UInt16) -> UInt8 {
        switch globalAddress {
            
        case Memory.cartridgeRomAddressRange:
            if isBootRomOverlayed && Self.biosAddressRange.contains(globalAddress) {
                return Self.bios[globalAddress]
            } else {
                return cartridge!.read(address: globalAddress) // TODO: Fixo.
            }
            
        case Memory.cartridgeRamAddressRange:
            return cartridge!.read(address: globalAddress) // TODO: Fixo.
            
        case Memory.videoRamAddressRange:
            return PPU.shared.readVRAM(globalAddress: globalAddress)
            
        case Memory.addressLY:
            return PPU.shared.currentScanlineIndex
            
        case Memory.addressLYC:
            return PPU.shared.coincidenceRegister
            
        case Memory.addressLCDS:
            return PPU.shared.statusRegister
            
        case Memory.addressLCDC:
            return PPU.shared.controlRegister
            
        case Memory.addressJoypad:
            return Joypad.shared.readJoypad()
            
        case Memory.addressGlobalAPURange,
            Memory.addressChannel1Range,
            Memory.addressChannel2Range,
            Memory.addressChannel3Range,
            Memory.addressChannel3WavePatternsRange,
            Memory.addressChannel4Range:
            return APU.shared.read(address: globalAddress)
            
        case Memory.addressDIV:
            return MasterClock.shared.divRegister
            
        case Memory.addressTIMA:
            return MasterClock.shared.timaRegister
            
        case Memory.addressTMA:
            return MasterClock.shared.tmaRegister
            
        case Memory.addressTAC:
            return MasterClock.shared.tacRegister

        default:
            return unsafeReadValue(globalAddress: globalAddress)
        }
    }
    
    func unsafeReadValue(globalAddress: UInt16) -> UInt8 {
        let localAddress = globalAddress - Memory.internalMemoryAddressRange.lowerBound
        return memoryMap[localAddress]
    }
    
    func safeWriteValue(_ value: UInt8, globalAddress: UInt16) {
        
        switch globalAddress {
            
        case Memory.cartridgeRomAddressRange, Memory.cartridgeRamAddressRange:
            cartridge?.write(value, address: globalAddress)
            return
            
        case Memory.videoRamAddressRange:
            PPU.shared.writeVRAM(globalAddress: globalAddress, value: value)
            
        case Memory.addressGlobalAPURange,
            Memory.addressChannel1Range,
            Memory.addressChannel2Range,
            Memory.addressChannel3Range,
            Memory.addressChannel3WavePatternsRange,
            Memory.addressChannel4Range:
            APU.shared.write(value, address: globalAddress)
            
        case Memory.biosDeactivateAddress:
            if value == 1 {
                isBootRomOverlayed = false
            }
            unsafeWriteValue(value, globalAddress: globalAddress)
            
        case Memory.addressLY:
            // If the current scanline is attempted to be manually changed, set it to zero instead
            PPU.shared.currentScanlineIndex = 0
            
        case Memory.addressLYC:
            PPU.shared.coincidenceRegister = value
            
        case Memory.addressLCDS:
            PPU.shared.statusRegister = value
            
        case Memory.addressLCDC:
            PPU.shared.controlRegister = value
            
        case Memory.addressDMATransferTrigger:
            dmaTransfer(byte: value)
            
        case Memory.echoRamAddressRange:
            // Anything writted to this range (0xE000 - 0xFDFF) is also written to 0xC000-0xDDFF.
            unsafeWriteValue(value, globalAddress: globalAddress)
            safeWriteValue(value, globalAddress: globalAddress &- Memory.echoRamOffset)
            
        case Memory.addressDIV:
            // If anything tries to write to this, then it should instead just be cleared.
            MasterClock.shared.clearDIV()
            
        case Memory.addressTIMA:
            MasterClock.shared.timaRegister = value
            
        case Memory.addressTMA:
            MasterClock.shared.tmaRegister = value
            
        case Memory.addressTAC:
            MasterClock.shared.writeTacRegister(value)
            
        case Memory.probitedAddressRange:
            return
            
        default:
            // Standard write
            unsafeWriteValue(value, globalAddress: globalAddress)
        }
    }
    
    func unsafeWriteValue(_ value: UInt8, globalAddress: UInt16) {
        let localAddress = globalAddress - Memory.internalMemoryAddressRange.lowerBound
        memoryMap[localAddress] = value
    }
    
    func getRAMSnapshot() -> Data {
        cartridge!.getRAMSnapshot()
    }
}

// MARK: - Interrupts

extension MMU {
    
    var hasPendingAndEnabledInterrupt: Bool {
        let interruptByte = unsafeReadValue(globalAddress: Memory.addressIE) & unsafeReadValue(globalAddress: Memory.addressIF)
        return interruptByte & 0b0001_1111 != 0
    }
    
    func getNextPendingAndEnabledInterrupt() -> UInt16? {
        var interruptFlags = unsafeReadValue(globalAddress: Memory.addressIF)
        let interuptEnable = unsafeReadValue(globalAddress: Memory.addressIE)
        let interruptByte = interuptEnable & interruptFlags
        
        // Priority is simply the bit order

        if interruptByte.checkBit(Memory.vBlankInterruptBitIndex) {
            interruptFlags.clearBit(Memory.vBlankInterruptBitIndex)
            unsafeWriteValue(interruptFlags, globalAddress: Memory.addressIF)
            return Memory.addressVBlankInterrupt
        }
        
        if interruptByte.checkBit(Memory.lcdInterruptBitIndex) {
            interruptFlags.clearBit(Memory.lcdInterruptBitIndex)
            unsafeWriteValue(interruptFlags, globalAddress: Memory.addressIF)
            return Memory.addressLcdInterrupt
        }
        
        if interruptByte.checkBit(Memory.timerInterruptBitIndex) {
            interruptFlags.clearBit(Memory.timerInterruptBitIndex)
            unsafeWriteValue(interruptFlags, globalAddress: Memory.addressIF)
            return Memory.addressTimerInterrupt
        }
        
        if interruptByte.checkBit(Memory.serialInterruptBitIndex) {
            interruptFlags.clearBit(Memory.serialInterruptBitIndex)
            unsafeWriteValue(interruptFlags, globalAddress: Memory.addressIF)
            return Memory.addressSerialInterrupt
        }

        if interruptByte.checkBit(Memory.joypadInterruptBitIndex) {
            interruptFlags.clearBit(Memory.joypadInterruptBitIndex)
            unsafeWriteValue(interruptFlags, globalAddress: Memory.addressIF)
            return Memory.addressJoypadInterrupt
        }
        
        return nil
    }
    
    func requestVBlankInterrupt() {
        requestInterrupt(bitIndex: Memory.vBlankInterruptBitIndex)
    }
    
    func requestLCDInterrupt() {
        requestInterrupt(bitIndex: Memory.lcdInterruptBitIndex)
    }
    
    func requestTimerInterrupt() {
        requestInterrupt(bitIndex: Memory.timerInterruptBitIndex)
    }
    
    func requestSerialInterrupt() {
        requestInterrupt(bitIndex: Memory.serialInterruptBitIndex)
    }
    
    func requestJoypadInterrupt() {
        requestInterrupt(bitIndex: Memory.joypadInterruptBitIndex)
    }
    
    private func requestInterrupt(bitIndex: Int) {
        var interruptFlags = unsafeReadValue(globalAddress: Memory.addressIF)
        interruptFlags.setBit(bitIndex)
        unsafeWriteValue(interruptFlags, globalAddress: Memory.addressIF)
    }
}

// MARK: - DMA Transfer

extension MMU {
    
    private func dmaTransfer(byte: UInt8) {
        let sourceAddress = UInt16(byte) << 8
        (0..<Memory.dmaTransferSize).forEach { addressOffset in
            let value = unsafeReadValue(globalAddress: sourceAddress + addressOffset)
            unsafeWriteValue(value, globalAddress: Memory.addressDMADestination + addressOffset)
        }
    }
}

// MARK: - BIOS

extension MMU {
    
    private static let biosAddressRange: Range<UInt16> = 0..<UInt16(bios.count)
    
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
