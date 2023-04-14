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
    private let numberOfRomBanks: UInt8
    private let ramBanks: [[UInt8]]
    
    private var bankMode: BankMode = .ramBank
    private var ramEnabled = false
    private var selectedRomBankIndex: UInt8 = 1
    private var selectedRamBankIndex: UInt8 = 0
    
    
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
        
        let emptyRamBank = Array(repeating: UInt8.min, count: Self.ramBankSize)
        ramBanks = Array(repeating: emptyRamBank, count: numberOfRamBanks)
    }
    
    func read(address: UInt16) -> UInt8 {
        switch address {
        case Memory.fixedRomBankAddressRange:
            return data[address]
        case Memory.switchableRomBankAddressRange:
            return readFromSwitchableRomBank(address: address)
        case Memory.switchableRamBankAddressRange:
            return readFromSwitchableRamBank(address: address)
        default:
            fatalError("Tried to read invalid address from ROM")
        }
    }
    
    mutating func write(_ value: UInt8, address: UInt16) {
        switch address {
        case Memory.ramEnableAddressRange:
            enableDisableRam(value: value)
        case Memory.romBankSelectAddressRange:
            selectedRomBankIndex(value: value)
        }
    }
}

// MARK: - Rom Banking

extension ROM {
    
    private func readFromSwitchableRomBank(address: UInt16) -> UInt8 {
        // Address is confirmed in range of 0x4000...0x7FFF at this point
        let adjustedAddress = address - Memory.switchableRomBankAddressRange.lowerBound // Get address in range of 0x0000...0x3FFF
        let offset = Self.romBankSize * UInt16(selectedRomBankIndex)
        let romAddress = adjustedAddress + offset
        return data[romAddress]
    }
    
    // None of this will make sense unless you read the following: https://gbdev.io/pandocs/MBC1.html
    private mutating func selectRomBankIndex(value: UInt8) {
        let currentValueUpperTwoBits: UInt8 = selectedRomBankIndex & 0b0110_0000
        let newValueLowerFiveBits = value & 0b0001_1111
        
        var newValue = newValueLowerFiveBits
        
        // If the ROM Bank Number is set to a higher value than the number of banks in the cart, the bank number is masked to the required number of bits.
        // e.g. a 256 KiB cart only needs a 4-bit bank number to address all of its 16 banks, so this register is masked to 4 bits.
        if (newValue > numberOfRomBanks) {
            newValue = (newValue << numberOfRomBanks.leadingZeroBitCount) >> numberOfRomBanks.leadingZeroBitCount
        }
        
        // Yes, we check `newValueLowerFiveBits` to see if we need to set `newValue`.
        // This is deliberate.
        if newValueLowerFiveBits == 0 {
            newValue = 1
        }
        
        newValue |= currentValueUpperTwoBits
        
        return selectedRomBankIndex = newValue
    }
}

// MARK: - Ram Banking

extension ROM {
    
    private func readFromSwitchableRamBank(address: UInt16) -> UInt8 {
        guard ramEnabled else { return 0xFF } // Most likely return value
        // Address is confirmed in range of 0xA000...0xBFFF at this point
        let adjustedAddress = address - Memory.switchableRamBankAddressRange.lowerBound // Get address in range of 0x0000...0x1FFF
        return ramBanks[selectedRamBankIndex][adjustedAddress]
    }
    
    private mutating func enableDisableRam(value: UInt8) {
        let maskedValue = value & Self.ramEnableDisableMask
        ramEnabled = maskedValue == Self.ramEnable
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
        case romBank
        case ramBank
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
    
    private static let ramEnableDisableMask: UInt8 = 0b1111
    private static let ramEnable: UInt8 = 0xA // Any value other than this disables RAM
}
