//
//  BinaryInteger+Rotation.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 15/8/21.
//

import Foundation

// Ref: https://stackoverflow.com/a/67745531

extension BinaryInteger {
    
    func bitwiseRightRotation(amount: Int) -> Self {
        let amount = amount % bitWidth // Reduce to the range 0...bitWidth
        return (self >> amount) | (self << (bitWidth - amount))
    }
    
    func bitwiseLeftRotation(amount: Int) -> Self {
        let amount = amount % bitWidth // Reduce to the range 0...bitWidth
        return (self << amount) | (self >> (bitWidth - amount))
    }
}
