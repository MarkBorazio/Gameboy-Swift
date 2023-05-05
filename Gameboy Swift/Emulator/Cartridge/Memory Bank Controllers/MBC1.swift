//
//  MBC1.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 16/4/2023.
//

import Foundation

// Quite similar to MBC3
class MBC1 {
    
    private enum BankMode {
        case mode0 // Commonly referred to as ROM banking mode
        case mode1 // Commonly referred to as RAM banking mode
    }
    
    private let rom: [UInt8]
    private var ram: [UInt8]
    private let numberOfRomBanks: Int
    
    private var bankMode: BankMode = .mode0
    private var bankRegister1: UInt8 = 1
    private var bankRegister2: UInt8 = 0
    private var ramEnabled = false
    
    init(rom: [UInt8], numberOfRomBanks: Int, numberOfRamBanks: Int) {
        self.rom = rom
        self.numberOfRomBanks = numberOfRomBanks
        
        let totalRam = numberOfRamBanks * Cartridge.ramBankSize
        ram = Array(repeating: UInt8.min, count: totalRam)
    }
    
    private func setBankMode(value: UInt8) {
        let newValue = value & 0b0000_0001
        switch newValue {
        case Self.bankMode0: bankMode = .mode0
        case Self.bankMode1: bankMode = .mode1
        default:
            fatalError("Unhandled bank mode value set. Got \(newValue.hexString()).")
        }
    }
    
    private func setBankRegister1(value: UInt8) {
        var newValue = value & 0b0001_1111

        if newValue == 0 {
            newValue = 1
        }
        
        bankRegister1 = newValue
    }
    
    private func setBankRegister2(value: UInt8) {
        bankRegister2 = value & 0b0000_0011
    }
}

// MARK: - ROM Banking

extension MBC1 {
    
    // Ref: https://gekkio.fi/files/gb-docs/gbctr.pdf
    // Chapter 8
    private func readFromFixedRomBank(address: UInt16) -> UInt8 {
        let effectiveRomBankIndex: UInt8 // Bits 0 - 6
        switch bankMode {
        case .mode0: effectiveRomBankIndex = 0
        case .mode1: effectiveRomBankIndex = bankRegister2 << 5
        }
        
        return readRomBank(address: address, effectiveRomBankIndex: effectiveRomBankIndex)
    }
    
    private func readFromSwitchableRomBank(address: UInt16) -> UInt8 {
        let effectiveRomBankIndex: UInt8 = (bankRegister2 << 5) | bankRegister1 // Bits 0 - 6
        return readRomBank(address: address, effectiveRomBankIndex: effectiveRomBankIndex)
    }
    
    private func readRomBank(address: UInt16, effectiveRomBankIndex: UInt8) -> UInt8 {
        let addressWithinBank = address & 0b0011_1111_1111_1111 // Bits 0 - 13
        
        // If the ROM Bank Number is set to a higher value than the number of banks in the cart, the bank number is masked to the required number of bits.
        // e.g. a 256 KiB cart only needs a 4-bit bank number to address all of its 16 banks, so this register is masked to 4 bits.
        let mask = (1 << numberOfRomBanks.minimumBitWidth) - 1
        let adjustedEffectiveRomBankIndex = effectiveRomBankIndex & UInt8(mask)
            
        let romAddress = (UInt32(adjustedEffectiveRomBankIndex) << 14) | UInt32(addressWithinBank)
        return rom[romAddress]
    }
}

// MARK: - RAM Banking

extension MBC1 {
    
    private func enableDisableRam(value: UInt8) {
        let maskedValue = value & 0b0000_1111
        ramEnabled = maskedValue == Self.ramEnable
    }
    
    private func readRamBank(address: UInt16) -> UInt8 {
        guard ramEnabled else { return 0xFF } // In practice, this is not guaranteed to be 0xFF, but it is the most likely return value.
        
        let ramAddress = convertToRamAddress(address: address)
        guard ramAddress < ram.count else {
            print("ERROR: Invalid read RAM address")
            return 0xFF
        }
        return ram[ramAddress]
    }
    
    private func writeRamBank(_ value: UInt8, address: UInt16) {
        guard ramEnabled else { return }
        
        let ramAddress = convertToRamAddress(address: address)
        guard ramAddress < ram.count else {
            print("ERROR: Invalid write RAM address")
            return
        }
        ram[ramAddress] = value
    }
    
    private func convertToRamAddress(address: UInt16) -> UInt32 {
        let addressWithinBank = address & 0b0001_1111_1111_1111 // Bits 0 - 12
        
        let effectiveRamBankIndex: UInt8 // Bits 0 - 1
        switch bankMode {
        case .mode0: effectiveRamBankIndex = 0
        case .mode1: effectiveRamBankIndex = bankRegister2
        }
        
        let ramAddress = (UInt32(effectiveRamBankIndex) << 13) | UInt32(addressWithinBank)
        return ramAddress
    }
}

// MARK: - MemoryBankController

extension MBC1: MemoryBankController {
    
    func write(value: UInt8, address: UInt16) {
        switch address {
        case Memory.ramEnableAddressRange:
            enableDisableRam(value: value)
        case Memory.setBankRegister1AddressRange:
            setBankRegister1(value: value)
        case Memory.setBankRegister2AddressRange:
            setBankRegister2(value: value)
        case Memory.switchableRamBankAddressRange:
            writeRamBank(value, address: address)
        case Memory.setBankModeAddressRange:
            setBankMode(value: value)
        default:
            fatalError("Unhandled write address sent to cartridge. Got \(address.hexString()).")
        }
    }
    
    func read(address: UInt16) -> UInt8 {
        switch address {
        case Memory.fixedRomBankAddressRange:
            return readFromFixedRomBank(address: address)
        case Memory.switchableRomBankAddressRange:
            return readFromSwitchableRomBank(address: address)
        case Memory.switchableRamBankAddressRange:
            return readRamBank(address: address)
        default:
            fatalError("Unhandled read address sent to cartridge. Got \(address.hexString()).")
        }
    }
    
    func getRAMSnapshot() -> Data {
        return Data(ram)
    }
}

// MARK: - Constants

extension MBC1 {
    
    // Bank Mode
    private static let bankMode0: UInt8 = 0
    private static let bankMode1: UInt8 = 1
    
    // Rom Bank
    private static let standardRomBankIndices: ClosedRange<UInt8> = 0x01...0x1F
    private static let extendedRomBankIndices: ClosedRange<UInt8> = 0x20...0x7F
    
    // Ram Bank
    private static let validRamBankIndices: ClosedRange<UInt8> = 0x00...0x03
    private static let ramEnable: UInt8 = 0xA // Any value other than this disables RAM
}
