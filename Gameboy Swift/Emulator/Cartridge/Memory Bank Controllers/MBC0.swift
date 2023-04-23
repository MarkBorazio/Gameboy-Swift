//
//  MBC0.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 16/4/2023.
//

import Foundation

class MBC0 {
    
    private let rom: [UInt8]
    private var ram: [UInt8]
    
    init(rom: [UInt8]) {
        self.rom = rom
        ram = Array(repeating: UInt8.min, count: Cartridge.ramBankSize)
    }
}

extension MBC0: MemoryBankController {
    
    func write(value: UInt8, address: UInt16) {
        switch address {
        case Memory.switchableRamBankAddressRange:
            ram[address] = value
        default:
            print("Unhandled write address sent to cartridge. Got \(address.hexString()).")
        }
    }
    
    func read(address: UInt16) -> UInt8 {
        switch address {
        case Memory.fixedRomBankAddressRange, Memory.switchableRomBankAddressRange:
            return rom[address]
        case Memory.switchableRamBankAddressRange:
            return ram[address]
        default:
            fatalError("Unhandled read address sent to cartridge. Got \(address.hexString()).")
        }
    }
}
