//
//  ROM.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

struct ROM {
    
    let data: [UInt8]
    private let mbcType: MBCType
    private let numberOfRomBanks: Int
    private var ram: [UInt8]
    
    private var bankMode: BankMode = .mode0
    private var ramEnabled = false
    private var selectedRomBankIndex: UInt8 = 1
    private var selectedRamBankIndex: UInt8 = 0
    
    private var bankRegister1: UInt8 = 1
    private var bankRegister2: UInt8 = 0
    
    
    init(fileName: String) throws {
        let url = Bundle.main.url(forResource: fileName, withExtension: "gb")!
        let romData = try Data(contentsOf: url)
        data = [UInt8](romData)
    
        let cartridgeType = data[Memory.cartridgeTypeAddress]
        switch cartridgeType {
        case Self.mbcType0: mbcType = .mbc0
        case Self.mbcType1: mbcType = .mbc1
        case Self.mbcType2: mbcType = .mbc2
        case Self.mbcType3: mbcType = .mbc3
        case Self.mbcType5: mbcType = .mbc5
        case Self.mbcType6: mbcType = .mbc6
        case Self.mbcType7: mbcType = .mbc7
        default:
            print("Got unrecognised Cartridge Type: \(cartridgeType.hexString())")
            mbcType = .mbc0
        }
        
        // ROM
        let numberOfRomBanksRaw = data[Memory.numberOfRomBanksAddress]
        switch numberOfRomBanksRaw {
        case Self.numRomBanks2: numberOfRomBanks = 2
        case Self.numRomBanks4: numberOfRomBanks = 4
        case Self.numRomBanks8: numberOfRomBanks = 8
        case Self.numRomBanks16: numberOfRomBanks = 16
        case Self.numRomBanks32: numberOfRomBanks = 32
        case Self.numRomBanks64: numberOfRomBanks = 64
        case Self.numRomBanks128: numberOfRomBanks = 128
        case Self.numRomBanks256: numberOfRomBanks = 256
        case Self.numRomBanks512: numberOfRomBanks = 512
        default:
            print("Got unrecognised number of rom banks: \(numberOfRomBanksRaw.hexString())")
            numberOfRomBanks = 2
        }
        
        
        // RAM
        let numberOfRamBanks: Int
        let numberOfRamBanksRaw = data[Memory.numberOfRamBanksAddress]
        switch numberOfRamBanksRaw {
        case Self.noRamBanks: numberOfRamBanks = 0
        case Self.oneRamBank: numberOfRamBanks = 1
        case Self.fourRamBanks: numberOfRamBanks = 4
        case Self.sixteenRamBanks: numberOfRamBanks = 16
        case Self.eightRamBanks: numberOfRamBanks = 8
        default:
            print("Got unrecognised number of ram banks: \(numberOfRamBanksRaw.hexString())")
            numberOfRamBanks = 0
        }
        
        let totalRam = numberOfRamBanks * Self.ramBankSize
        ram = Array(repeating: UInt8.min, count: totalRam)
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
    
    mutating func write(_ value: UInt8, address: UInt16) {
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
    
    private mutating func setBankMode(value: UInt8) {
        let newValue = value & 0b0000_0001
        switch newValue {
        case Self.bankMode0: bankMode = .mode0
        case Self.bankMode1: bankMode = .mode1
        default:
            fatalError("Unhandled bank mode value set. Got \(newValue.hexString()).")
        }
    }
    
    private mutating func setBankRegister1(value: UInt8) {
        var newValue = value & 0b0001_1111

        if newValue == 0 {
            newValue = 1
        }
        
        bankRegister1 = newValue
    }
    
    private mutating func setBankRegister2(value: UInt8) {
        bankRegister2 = value & 0b0000_0011
    }
}

// MARK: - ROM Banking

extension ROM {
    
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
        var adjustedEffectiveRomBankIndex = effectiveRomBankIndex
        let maximumBitWidth = UInt8(numberOfRomBanks.minimumBitWidth)
        if (effectiveRomBankIndex.minimumBitWidth > maximumBitWidth) {
            let mask = 2^maximumBitWidth - 1
            adjustedEffectiveRomBankIndex &= mask
        }
        
        
        let romAddress = (UInt32(adjustedEffectiveRomBankIndex) << 14) | UInt32(addressWithinBank)
        return data[romAddress]
    }
}

// MARK: - RAM Banking

extension ROM {
    
    private mutating func enableDisableRam(value: UInt8) {
        let maskedValue = value & 0b0000_1111
        ramEnabled = maskedValue == Self.ramEnable
    }
    
    private func readRamBank(address: UInt16) -> UInt8 {
        guard ramEnabled else { return 0xFF } // In practice, this is not guaranteed to be 0xFF, but it is the most likely return value.
        
        let ramAddress = convertToRamAddress(address: address)
        guard ramAddress <= ram.count else {
            print("ERROR: Invalid read RAM address")
            return 0xFF
        }
        return ram[ramAddress]
    }
    
    private mutating func writeRamBank(_ value: UInt8, address: UInt16) {
        guard ramEnabled else { return }
        
        let ramAddress = convertToRamAddress(address: address)
        guard ramAddress <= ram.count else {
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

extension ROM {
    
    private enum MBCType {
        case mbc0
        case mbc1
        case mbc2
        case mbc3
        case mbc5
        case mbc6
        case mbc7
    }
    
    private enum BankMode {
        case mode0 // Commonly referred to as ROM banking mode
        case mode1 // Commonly referred to as RAM banking mode
    }
}

// MARK: - Constants

extension ROM {
    
    // MARK: - Memory Bank Controller (MBC)
    
    private static let mbcType0: UInt8 = 0x00
    private static let mbcType1: ClosedRange<UInt8> = 0x01...0x03
    private static let mbcType2: ClosedRange<UInt8> = 0x05...0x06
    private static let mbcType3: ClosedRange<UInt8> = 0x0F...0x13
    private static let mbcType5: ClosedRange<UInt8> = 0x19...0x1E
    private static let mbcType6: UInt8 = 0x20
    private static let mbcType7: UInt8 = 0x22
    
    private static let bankMode0: UInt8 = 0
    private static let bankMode1: UInt8 = 1
    
    
    // MARK: - Rom Bank
    
    private static let romBankSize: UInt16 = 16 * 1024 // 16KB (0x4000) (same as start of switchable rom bank address range)
    private static let standardRomBankIndices: ClosedRange<UInt8> = 0x01...0x1F
    private static let extendedRomBankIndices: ClosedRange<UInt8> = 0x20...0x7F
    
    private static let numRomBanks2: UInt8 = 0x0
    private static let numRomBanks4: UInt8 = 0x1
    private static let numRomBanks8: UInt8 = 0x2
    private static let numRomBanks16: UInt8 = 0x3
    private static let numRomBanks32: UInt8 = 0x4
    private static let numRomBanks64: UInt8 = 0x5
    private static let numRomBanks128: UInt8 = 0x6
    private static let numRomBanks256: UInt8 = 0x7
    private static let numRomBanks512: UInt8 = 0x8
    
    // MARK: - Ram Bank
    
    private static let ramBankSize:Int = 8 * 1024 // 8KB
    
    private static let validRamBankIndices: ClosedRange<UInt8> = 0x00...0x03
    
    private static let noRamBanks: UInt8 = 0x0
    private static let oneRamBank: UInt8 = 0x2
    private static let fourRamBanks: UInt8 = 0x3
    private static let sixteenRamBanks: UInt8 = 0x4
    private static let eightRamBanks: UInt8 = 0x5

    private static let ramEnable: UInt8 = 0xA // Any value other than this disables RAM
    
    // MARK: - Miscellaneous
    
    private static let romBankUpperBitsAndRamBankMask: UInt8 = 0b11
}
