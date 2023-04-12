//
//  ROM.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

struct ROM {
    
    let data: [UInt8]
    let mbcType: MBCType
    let numberOfRamBanks: Int
    
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
        
        let numberOfRamBanksRaw = data[Memory.ramBanksAddress]
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
    }
}

extension ROM {
    
    // MARK: - Memory Bank Controller (MBC)
    
    enum MBCType {
        case mbc0
        case mbc1
        case mbc2
        case mbc3
        case mbc5
        case mbc6
        case mbc7
    }
    
    private static let mbcType0: UInt8 = 0x00
    private static let mbcType1: ClosedRange<UInt8> = 0x01...0x03
    private static let mbcType2: ClosedRange<UInt8> = 0x05...0x06
    private static let mbcType3: ClosedRange<UInt8> = 0x0F...0x13
    private static let mbcType5: ClosedRange<UInt8> = 0x19...0x1E
    private static let mbcType6: UInt8 = 0x20
    private static let mbcType7: UInt8 = 0x22
    
    
    // MARK: - Ram Bank
    
    private static let ramBankSize:Int = 8 * 1024 // 8KB
    
    private static let noRamBanks: UInt8 = 0x0
    private static let oneRamBank: UInt8 = 0x2
    private static let fourRamBanks: UInt8 = 0x3
    private static let sixteenRamBanks: UInt8 = 0x4
    private static let eightRamBanks: UInt8 = 0x5
}
