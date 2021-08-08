//
//  CPU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

class CPU {
    
    // Registers
    private var af: UInt16 = 0
    private var bc: UInt16 = 0
    private var de: UInt16 = 0
    private var hl: UInt16 = 0
    private var sp: UInt16 = 0
    private var pc: UInt16 = 0
    
    private func executeInstruction() {
        
        let opcode = readNextByte()
        
        switch opcode {
        case 0x00: noOp()
        case 0x01: loadShortIntoBC()
        case 0x02: loadAIntoLocationBC()
        case 0x03: incrementBC()
        case 0x04: incrementB()
        case 0x05: decrementB()
        case 0x06: loadByteIntoB()
        case 0x07: rotateALeftWithCarry()
        case 0x08: loadSPIntoAddress()
        case 0x09: addBCtoHL()
        case 0x0A: loadLocationBCIntoA()
        case 0x0B: decrementBC()
        case 0x0C: incrementC()
        case 0x0D: decrementC()
        case 0x0E: loadByteIntoC()
        case 0x0F: rotateARightWithCarry()
            
            
        default: fatalError("Encountered unknown opcode.")
        }
    }
    
    private func readNextByte() -> UInt8 {
//        let opcode = memory.readOpcode(address: pc)
        let opcode: UInt8 = 0x01
        pc &+= 1
        return opcode
    }
}

// MARK: - 8-bit Instructions

extension CPU {
    
    private func noOp() {
        // No Operation
    }
    
    private func loadShortIntoBC() {
        
    }
    
    private func loadAIntoLocationBC() {
        
    }
    
    private func incrementBC() {
        
    }
    
    private func incrementB() {
        
    }
    
    private func decrementB() {
        
    }
    
    private func loadByteIntoB() {
        
    }
    
    private func rotateALeftWithCarry() {
        
    }
    
    private func loadSPIntoAddress() {
        
    }
    
    private func addBCtoHL() {
        
    }
    
    // Verify
    private func loadLocationBCIntoA() {
        
    }
    
    private func decrementBC() {
        
    }
    
    private func incrementC() {
        
    }
    
    private func decrementC() {
        
    }
    
    private func loadByteIntoC() {
        
    }
    
    private func rotateARightWithCarry() {
        
    }
}
