//
//  ROM.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

struct ROM {
    
    let data: [UInt8]
    
    init(fileName: String) throws {
        let url = Bundle.main.url(forResource: fileName, withExtension: "gb")!
        let romData = try Data(contentsOf: url)
        data = [UInt8](romData)
    
        // TODO: Figure out MBC
//        let cartridgeType = data[Self.cartridgeTypeAddress]
//        switch cartridgeType {
//        case 0x00:
//        case 0x01:
//        case 0x02:
//        case 0x03:
//        case 0x05:
//        case 0x06:
//        case 0x08:
//        case 0x09:
//        case 0x0B:
//        case 0x0C:
//        case 0x0D:
//        case 0x0F:
//        case 0x10:
//        case 0x11:
//        case 0x12:
//        case 0x13:
//        case 0x19:
//        case 0x1A:
//        case 0x1B:
//        case 0x1C:
//        case 0x1D:
//        case 0x1E:
//        case 0x20:
//        case 0x22:
//        case 0xFC:
//        case 0xFD:
//        case 0xFE:
//        case 0xFF:
//        }
    }
}

// MARK: - Constants

extension ROM {
    
    private static let headerAddressRange: ClosedRange<UInt16> = 0x0100...0x014F
    private static let cartridgeTypeAddress: UInt16 = 0x0147
}
