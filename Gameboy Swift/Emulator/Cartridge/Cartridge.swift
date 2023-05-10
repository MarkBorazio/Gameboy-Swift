//
//  Cartridge.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

struct Cartridge {
    
    let romURL: URL
    let saveDataURL: URL
    private let mbc: MemoryBankController
    
    init(romURL: URL) throws {
        self.romURL = romURL
        
        saveDataURL = try GameBoy.getSavesFolderURL()
            .appendingPathComponent(romURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("gbswiftsave")
        
        let romData = try Data(contentsOf: romURL)
        
        let saveData: Data?
        if FileManager.default.fileExists(atPath: saveDataURL.path) {
            saveData = try Data(contentsOf: saveDataURL)
        } else {
            saveData = nil
        }
        
        let rom = [UInt8](romData)
        
        // ROM Banks
        let numberOfRomBanks: Int
        let numberOfRomBanksShift = rom[Memory.numberOfRomBanksAddress]
        if Self.validNumRomBanksShift.contains(numberOfRomBanksShift) {
            numberOfRomBanks = 2 << numberOfRomBanksShift
        } else {
            Coordinator.instance.crash(message: "Got unrecognised number of rom banks: \(numberOfRomBanksShift.hexString())")
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
            Coordinator.instance.crash(message: "Got unrecognised number of ram banks: \(numberOfRamBanksRaw.hexString())")
        }
        
        // MBC
        let cartridgeType = rom[Memory.cartridgeTypeAddress]
        switch cartridgeType {
        case Self.mbcType0: mbc = MBC0(rom: rom)
        case Self.mbcType1: mbc = MBC1(rom: rom, numberOfRomBanks: numberOfRomBanks, numberOfRamBanks: numberOfRamBanks)
        case Self.mbcType2: Coordinator.instance.crash(message: "MBC2 not yet implemented")
        case Self.mbcType3: mbc = MBC3(rom: rom, numberOfRomBanks: numberOfRomBanks, numberOfRamBanks: numberOfRamBanks, saveData: saveData)
        case Self.mbcType5: Coordinator.instance.crash(message: "MBC5 not yet implemented")
        case Self.mbcType6: Coordinator.instance.crash(message: "MBC6 not yet implemented")
        case Self.mbcType7: Coordinator.instance.crash(message: "MBC7 not yet implemented")
        default:
            Coordinator.instance.crash(message: "Got unrecognised cartridge Type: \(cartridgeType.hexString())")
        }
    }
    
    func read(address: UInt16) -> UInt8 {
        mbc.read(address: address)
    }
    
    func write(_ value: UInt8, address: UInt16) {
        mbc.write(value: value, address: address)
    }
    
    func getRAMSnapshot() -> Data {
        mbc.getRAMSnapshot()
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
    private static let validNumRomBanksShift: ClosedRange<UInt8> = 0...8
    
    // Ram Bank
    static let ramBankSize: Int = 8 * 1024 // 8KB
    
    private static let noRamBanks: UInt8 = 0x0
    private static let oneRamBank: UInt8 = 0x2
    private static let fourRamBanks: UInt8 = 0x3
    private static let sixteenRamBanks: UInt8 = 0x4
    private static let eightRamBanks: UInt8 = 0x5
}
