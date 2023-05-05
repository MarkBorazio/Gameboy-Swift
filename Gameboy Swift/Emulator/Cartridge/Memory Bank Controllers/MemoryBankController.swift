//
//  MemoryBankController.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 16/4/2023.
//

import Foundation

protocol MemoryBankController {
    func write(value: UInt8, address: UInt16)
    func read(address: UInt16) -> UInt8
    func getRAMSnapshot() -> Data
}
