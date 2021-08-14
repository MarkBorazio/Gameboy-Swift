//
//  CPU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

class CPU {
    
    let memory = Memory()
    
    // Registers
    private var af: UInt16 = 0
    private var bc: UInt16 = 0
    private var de: UInt16 = 0
    private var hl: UInt16 = 0
    private var sp: UInt16 = 0
    private var pc: UInt16 = 0
    
    // Register Pair Convenience
    private var a: UInt8 {
        get { af.asBytes()[0] }
        set { af = UInt16(bytes: [newValue, f])! }
    }
    private var f: UInt8 {
        get { af.asBytes()[1] }
        set { af = UInt16(bytes: [a, newValue])! }
    }
    
    private var b: UInt8 {
        get { bc.asBytes()[0] }
        set { bc = UInt16(bytes: [newValue, c])! }
    }
    private var c: UInt8 {
        get { bc.asBytes()[1] }
        set { bc = UInt16(bytes: [b, newValue])! }
    }
    
    private var d: UInt8 {
        get { de.asBytes()[0] }
        set { de = UInt16(bytes: [newValue, e])! }
    }
    private var e: UInt8 {
        get { de.asBytes()[1] }
        set { de = UInt16(bytes: [d, newValue])! }
    }
    
    private var h: UInt8 {
        get { hl.asBytes()[0] }
        set { hl = UInt16(bytes: [newValue, l])! }
    }
    private var l: UInt8 {
        get { hl.asBytes()[1] }
        set { hl = UInt16(bytes: [h, newValue])! }
    }
    
    private func executeInstruction() {
        
        let opcode = fetchNextByte()
        
        switch opcode {
        case 0x00: noOp()
        case 0x01: loadShortIntoBC()
        case 0x02: loadAIntoAbsoluteBC()
        case 0x03: incrementBC()
        case 0x04: incrementB()
        case 0x05: decrementB()
        case 0x06: loadByteIntoB()
        case 0x07: rotateALeftWithCarry()
        case 0x08: loadSPIntoAddress()
        case 0x09: addBCtoHL()
        case 0x0A: loadAbsoluteBCIntoA()
        case 0x0B: decrementBC()
        case 0x0C: incrementC()
        case 0x0D: decrementC()
        case 0x0E: loadByteIntoC()
        case 0x0F: rotateARightWithCarry()
            
        default: fatalError("Encountered unknown opcode.")
        }
    }
    
    private func fetchNextByte() -> UInt8 {
        let opcode = memory.readValue(address: pc)
        pc &+= 1
        return opcode
    }
}

// MARK - Arithmetic Functions

extension CPU {
    
    // TODO: This.
}

// MARK: - 8-bit Instructions

extension CPU {
    
    private func noOp() {
        // No Operation
    }
    
    private func loadShortIntoBC() {
        let value = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        bc = value
    }
    
    private func loadAIntoAbsoluteBC() {
        memory.writeValue(a, address: bc)
    }
    
    private func incrementBC() {
        bc &+= 1
    }
    
    private func incrementB() {
        b &+= 1
    }
    
    private func decrementB() {
        b &-= 1
    }
    
    private func loadByteIntoB() {
        b = fetchNextByte()
    }
    
    private func rotateALeftWithCarry() {
        let rotatedA = a.bitwiseLeftRotation(amount: 1)
        a = rotatedA
        
        let carriedBit = (rotatedA >> 7) & 0b1
        f = f & (carriedBit << 4)
    }
    
    private func loadSPIntoAddress() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        memory.writeValue(sp.asBytes()[0], address: address)
        memory.writeValue(sp.asBytes()[1], address: address+1)
    }
    
    private func addBCtoHL() {
        hl &+= bc
    }
    
    private func loadAbsoluteBCIntoA() {
        a = memory.readValue(address: bc)
    }
    
    private func decrementBC() {
        bc &-= 1
    }
    
    private func incrementC() {
        c &+= 1
    }
    
    private func decrementC() {
        c &-= 1
    }
    
    private func loadByteIntoC() {
        c = fetchNextByte()
    }
    
    private func rotateARightWithCarry() {
        let rotatedA = a.bitwiseRightRotation(amount: 1)
        a = rotatedA
        
        let carriedBit = rotatedA & 0b1
        f = f & (carriedBit << 4)
    }
}
