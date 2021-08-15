//
//  UInt8+Extensions.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 15/8/21.
//

import Foundation

extension UInt8 {
    var lowNibble: UInt8 { self & 0b00001111 }
    var highNibble: UInt8 { (self & 0b11110000) >> 4 }
    
    func checkBit(_ n: Int) -> Bool {
        guard n < bitWidth else { return false }
        return (self >> n) == 0b1
    }
    
    mutating func setBit(_ n: Int) {
        guard n < bitWidth else { return }
        self |= (0b1 << n)
    }
    
    mutating func clearBit(_ n: Int) {
        guard n < bitWidth else { return }
        self &= ~(0b1 << n)
    }
    
    func addingReportingHalfCarry(_ rhs: Self) -> (newValue: Self, halfCarry: Bool) {
        let newValue = self &+ rhs
        let halfCarryFlag = (((self & 0xF) &+ (rhs & 0xF)) & 0x10) == 0x10
        return (newValue, halfCarryFlag)
    }
    
    func subtractingReportingHalfCarry(_ rhs: Self) -> (newValue: Self, halfCarry: Bool) {
        let newValue = self &- rhs
        let halfCarryFlag = (((self & 0xF) &- (rhs & 0xF)) & 0x10) == 0x10
        return (newValue, halfCarryFlag)
    }
}
