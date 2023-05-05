//
//  MBC3.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 16/4/2023.
//

import Foundation

// Quite similar to MBC1
class MBC3 {
    
    private let rom: [UInt8]
    private var ram: [UInt8]
    private let numberOfRomBanks: Int
    
    private var selectedRomBankIndex: UInt8 = 1
    private var ramAndRTCRegister: UInt8 = 0
    private var ramAndRTCEnabled = false
    private var realTimeClock = RealTimeClock.zeroValue
    
    init(rom: [UInt8], numberOfRomBanks: Int, numberOfRamBanks: Int, saveDataURL: URL?) {
        self.rom = rom
        self.numberOfRomBanks = numberOfRomBanks
        
        let totalRam = numberOfRamBanks * Cartridge.ramBankSize
        
        
        if let saveDataURL {
            let saveData = try! Data(contentsOf: saveDataURL)
            ram = Array<UInt8>(saveData)
        } else {
            ram = Array(repeating: UInt8.min, count: totalRam)
        }
    }
}

// MARK: - ROM Banking

extension MBC3 {
    
    private func setRomBankIndex(value: UInt8) {
        var newValue = value & 0b0111_1111

        if newValue == 0 {
            newValue = 1
        }
        
        selectedRomBankIndex = newValue
    }
    
    private func readFromFixedRomBank(address: UInt16) -> UInt8 {
        return readRomBank(address: address, romBankIndex: 0)
    }
    
    private func readFromSwitchableRomBank(address: UInt16) -> UInt8 {
        return readRomBank(address: address, romBankIndex: selectedRomBankIndex)
    }
    
    private func readRomBank(address: UInt16, romBankIndex: UInt8) -> UInt8 {
        let addressWithinBank = address & 0b0011_1111_1111_1111 // Bits 0 - 13
        
        // If the ROM Bank Number is set to a higher value than the number of banks in the cart, the bank number is masked to the required number of bits.
        // e.g. a 256 KiB cart only needs a 4-bit bank number to address all of its 16 banks, so this register is masked to 4 bits.
        let mask = (1 << numberOfRomBanks.minimumBitWidth) - 1
        let adjustedRomBankIndex = romBankIndex & UInt8(mask)
        
        let romAddress = (UInt32(adjustedRomBankIndex) << 14) | UInt32(addressWithinBank)
        return rom[romAddress]
    }
}

// MARK: - RAM Banking And RTC Registers

extension MBC3 {
    
    private func enableDisableRamAndRTC(value: UInt8) {
        let maskedValue = value & 0b0000_1111
        ramAndRTCEnabled = maskedValue == Self.ramAndRTCEnable
    }
    
    private func selectRamBankOrRTCRegister(value: UInt8) {
        guard Self.validRamBankIndices.contains(value) || Self.validRTCRegisterIndices.contains(value) else {
            print("ERROR: Invalid Ram and RTC Register value set. Got \(value.hexString()).")
            return
        }
        
        ramAndRTCRegister = value
    }
    
    private func readRamBankOrRTCRegister(address: UInt16) -> UInt8 {
        guard ramAndRTCEnabled else { return 0xFF } // In practice, this is not guaranteed to be 0xFF, but it is the most likely return value.
        
        switch ramAndRTCRegister {
        case Self.validRamBankIndices:
            let ramAddress = convertToRamAddress(address: address)
            guard ramAddress < ram.count else {
                print("ERROR: Invalid read RAM address")
                return 0xFF
            }
            return ram[ramAddress]
        case Self.rtcSecondsRegisterIndex:
            return realTimeClock.seconds
        case Self.rtcMinutesRegisterIndex:
            return realTimeClock.minutes
        case Self.rtcHoursRegisterIndex:
            return realTimeClock.hours
        case Self.rtcDaysLowRegisterIndex:
            return realTimeClock.dayLow
        case Self.rtcDaysHighRegisterIndex:
            return realTimeClock.dayHigh
        default:
            fatalError("Invalid RAM and RTC register value found when trying to read. Got \(ramAndRTCRegister.hexString()).")
        }
    }
    
    private func writeRamOrRTCRegisterBank(_ value: UInt8, address: UInt16) {
        guard ramAndRTCEnabled else { return }
        
        switch ramAndRTCRegister {
        case Self.validRamBankIndices:
            let ramAddress = convertToRamAddress(address: address)
            guard ramAddress < ram.count else {
                print("ERROR: Invalid write RAM address")
                return
            }
            ram[ramAddress] = value
        case Self.rtcSecondsRegisterIndex:
            realTimeClock.seconds = value
        case Self.rtcMinutesRegisterIndex:
            realTimeClock.minutes = value
        case Self.rtcHoursRegisterIndex:
            realTimeClock.hours = value
        case Self.rtcDaysLowRegisterIndex:
            realTimeClock.dayLow = value
        case Self.rtcDaysHighRegisterIndex:
            realTimeClock.dayHigh = value
        default:
            fatalError("Invalid RAM and RTC register value found when trying to write. Got \(ramAndRTCRegister.hexString()).")
        }
    }
    
    private func convertToRamAddress(address: UInt16) -> UInt32 {
        let addressWithinBank = address & 0b0001_1111_1111_1111 // Bits 0 - 12
        let ramAddress = (UInt32(ramAndRTCRegister) << 13) | UInt32(addressWithinBank)
        return ramAddress
    }
    
    private func latchClockData(value: UInt8) {
        if value == 0x1 { // TODO: Make sure it is zero first
            realTimeClock = .current
        }
    }
}

// MARK: - Real Time Clock (RTC)

extension MBC3 {
    
    private struct RealTimeClock {
        var seconds: UInt8
        var minutes: UInt8
        var hours: UInt8
        var dayLow: UInt8 // Lower 8 bits of Day Counter
        var dayHigh: UInt8 // Bit 0: Upper 1 bit of Day Counter | Bit 6: Carry Bit | Bit 7: Halt Flag
        
        static var current: RealTimeClock {
            let secondsSinceReference = Date.timeIntervalSinceReferenceDate
            let minutesSinceReference = secondsSinceReference / 60
            let hoursSinceReference = minutesSinceReference / 60
            let daysSinceReference = hoursSinceReference / 24

            let days = daysSinceReference.truncatingRemainder(dividingBy: 512) // Days is stored in 9 bits, meaning that max amount before overflow is 511
            let daysBytes = UInt16(days).asBytes() // days is guaranteed to fit in UInt16 since it won't be greater than 511

            let seconds = UInt8(secondsSinceReference.truncatingRemainder(dividingBy: 60))
            let minutes = UInt8(minutesSinceReference.truncatingRemainder(dividingBy: 60))
            let hours = UInt8(hoursSinceReference.truncatingRemainder(dividingBy: 24))
            let dayLow = daysBytes[0]
            let dayHigh = daysBytes[1] & 0b1 // TODO: Halt flag and day carry flag
        
            return RealTimeClock(seconds: seconds, minutes: minutes, hours: hours, dayLow: dayLow, dayHigh: dayHigh)
        }
        
        static let zeroValue = RealTimeClock(seconds: 0, minutes: 0, hours: 0, dayLow: 0, dayHigh: 0)
    }
}

// MARK: - MemoryBankController

extension MBC3: MemoryBankController {
    
    func write(value: UInt8, address: UInt16) {
        switch address {
        case Memory.ramEnableAddressRange:
            enableDisableRamAndRTC(value: value)
        case Memory.setBankRegister1AddressRange:
            setRomBankIndex(value: value)
        case Memory.setBankRegister2AddressRange:
            selectRamBankOrRTCRegister(value: value)
        case Memory.switchableRamBankAddressRange:
            writeRamOrRTCRegisterBank(value, address: address)
        case Memory.setBankModeAddressRange:
            latchClockData(value: value)
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
            return readRamBankOrRTCRegister(address: address)
        default:
            fatalError("Unhandled read address sent to cartridge. Got \(address.hexString()).")
        }
    }
    
    func getRAMSnapshot() -> Data {
        return Data(ram)
    }
}

// MARK: - Constants

extension MBC3 {
    
    // Bank Mode
    private static let bankMode0: UInt8 = 0
    private static let bankMode1: UInt8 = 1
    
    // Rom Bank
    private static let standardRomBankIndices: ClosedRange<UInt8> = 0x01...0x1F
    private static let extendedRomBankIndices: ClosedRange<UInt8> = 0x20...0x7F
    
    // Ram Bank and RTC
    private static let validRamBankIndices: ClosedRange<UInt8> = 0x00...0x03
    private static let ramAndRTCEnable: UInt8 = 0xA // Any value other than this disables RAM and the RTC
    
    private static let validRTCRegisterIndices: ClosedRange<UInt8> = 0x08...0x0C
    private static let rtcSecondsRegisterIndex: UInt8 = 0x08
    private static let rtcMinutesRegisterIndex: UInt8 = 0x09
    private static let rtcHoursRegisterIndex: UInt8 = 0x0A
    private static let rtcDaysLowRegisterIndex: UInt8 = 0x0B
    private static let rtcDaysHighRegisterIndex: UInt8 = 0x0C
}

