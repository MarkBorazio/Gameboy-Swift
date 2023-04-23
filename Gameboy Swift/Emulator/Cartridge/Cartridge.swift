//
//  Cartridge.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

struct Cartridge {
    
    private let mbc: MemoryBankController
    
    init(fileName: String) throws {
        let url = Bundle.main.url(forResource: fileName, withExtension: "gb")!
        let romData = try Data(contentsOf: url)
        let rom = [UInt8](romData)
        
        // ROM Banks
        let numberOfRomBanks: Int
        let numberOfRomBanksRaw = rom[Memory.numberOfRomBanksAddress]
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
            fatalError("Got unrecognised number of rom banks: \(numberOfRomBanksRaw.hexString())")
        }
        
        // RAM Banks
        let numberOfRamBanks: Int
        let numberOfRamBanksRaw = rom[Memory.numberOfRamBanksAddress]
        switch numberOfRamBanksRaw {
        case Self.noRamBanks: numberOfRamBanks = 0
        case Self.oneRamBank: numberOfRamBanks = 1
        case Self.fourRamBanks: numberOfRamBanks = 4
        case Self.sixteenRamBanks: numberOfRamBanks = 16
        case Self.eightRamBanks: numberOfRamBanks = 8
        default:
            fatalError("Got unrecognised number of ram banks: \(numberOfRamBanksRaw.hexString())")
        }
        
        // MBC
        let cartridgeType = rom[Memory.cartridgeTypeAddress]
        switch cartridgeType {
        case Self.mbcType0: mbc = MBC0(rom: rom)
        case Self.mbcType1: mbc = MBC1(rom: rom, numberOfRomBanks: numberOfRomBanks, numberOfRamBanks: numberOfRamBanks)
        case Self.mbcType2: fatalError("MBC2 not yet implemented")
        case Self.mbcType3: mbc = MBC3(rom: rom, numberOfRomBanks: numberOfRomBanks, numberOfRamBanks: numberOfRamBanks)
        case Self.mbcType5: fatalError("MBC5 not yet implemented")
        case Self.mbcType6: fatalError("MBC6 not yet implemented")
        case Self.mbcType7: fatalError("MBC7 not yet implemented")
        default:
            fatalError("Got unrecognised cartridge Type: \(cartridgeType.hexString())")
        }
    }
    
    func read(address: UInt16) -> UInt8 {
        mbc.read(address: address)
    }
    
    func write(_ value: UInt8, address: UInt16) {
        mbc.write(value: value, address: address)
    }
}

// MARK: - Constants

extension Cartridge {
    
    // Memory Bank Controller (MBC)
    private static let mbcType0: UInt8 = 0x00
    private static let mbcType1: ClosedRange<UInt8> = 0x01...0x03
    private static let mbcType2: ClosedRange<UInt8> = 0x05...0x06
    private static let mbcType3: ClosedRange<UInt8> = 0x0F...0x13
    private static let mbcType5: ClosedRange<UInt8> = 0x19...0x1E
    private static let mbcType6: UInt8 = 0x20
    private static let mbcType7: UInt8 = 0x22
    
    
    // Rom Bank
    private static let numRomBanks2: UInt8 = 0x0
    private static let numRomBanks4: UInt8 = 0x1
    private static let numRomBanks8: UInt8 = 0x2
    private static let numRomBanks16: UInt8 = 0x3
    private static let numRomBanks32: UInt8 = 0x4
    private static let numRomBanks64: UInt8 = 0x5
    private static let numRomBanks128: UInt8 = 0x6
    private static let numRomBanks256: UInt8 = 0x7
    private static let numRomBanks512: UInt8 = 0x8
    
    // Ram Bank
    static let ramBankSize: Int = 8 * 1024 // 8KB
    
    private static let noRamBanks: UInt8 = 0x0
    private static let oneRamBank: UInt8 = 0x2
    private static let fourRamBanks: UInt8 = 0x3
    private static let sixteenRamBanks: UInt8 = 0x4
    private static let eightRamBanks: UInt8 = 0x5
}
