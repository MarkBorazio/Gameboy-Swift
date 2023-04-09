//
//  BinaryInteger+Extensions.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 15/8/21.
//

import Foundation

extension BinaryInteger {
    
    func checkBit(_ n: Int) -> Bool {
        return (self >> n) & 0b1 == 0b1
    }
    
    func getBitValue(_ n: Int) -> Self {
        return (self >> n) & 0b1
    }
    
    mutating func setBit(_ n: Int) {
        guard n < bitWidth else { return }
        self |= (0b1 << n)
    }
    
    mutating func clearBit(_ n: Int) {
        guard n < bitWidth else { return }
        self &= ~(0b1 << n)
    }
    
    // Ref: https://stackoverflow.com/a/67745531
    
    func bitwiseRightRotation(amount: Int) -> Self {
        let amount = amount % bitWidth // Reduce to the range 0...bitWidth
        return (self >> amount) | (self << (bitWidth - amount))
    }
    
    func bitwiseLeftRotation(amount: Int) -> Self {
        let amount = amount % bitWidth // Reduce to the range 0...bitWidth
        return (self << amount) | (self >> (bitWidth - amount))
    }
    
    /// Returns a new value where the bit order is reversed
    ///
    /// ```
    /// let byte: UInt8 = 0b01100010
    /// let reversedByte = byte.reversedBits // 0b01000110
    /// ```
    var reversedBits: Self {
        var new = Self(0)
        for i in 0..<bitWidth {
            let bit = (self >> i) & 0b1
            let newBitIndex = (bitWidth - 1) - i
            let reversedBit = bit << (newBitIndex)
            new |= reversedBit
        }
        return new
    }
    
    func hexString(includePrefix: Bool = true) -> String {
        let hexWidth = bitWidth / 4
        var hexString = String(magnitude, radix: 16, uppercase: true)
        while hexString.count < hexWidth {
            hexString = "0" + hexString
        }
        
        if includePrefix {
            let prefix = (self >= 0) ? "0x" : "-0x"
            return prefix + hexString
        } else {
            return hexString
        }
    }
    
    var binaryString: String {
        var binaryString = String(self, radix: 2)
        while binaryString.count < bitWidth {
            binaryString = "0" + binaryString
        }
        return binaryString
    }
}
