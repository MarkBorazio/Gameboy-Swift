//
//  CPU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

// TODO: Consider using function builders
class CPU {
    
    static let shared = CPU()
    
    // Register Pairs
    private var af: UInt16 = 0x00
    private var bc: UInt16 = 0x00
    private var de: UInt16 = 0x00
    private var hl: UInt16 = 0x00
    private var sp: UInt16 = 0x00
    private var pc: UInt16 = 0x00
    
    // Individual Registers
    private var a: UInt8 {
        get { af.asBytes()[1] }
        set { af = UInt16(bytes: [f, newValue])! }
    }
    private var f: UInt8 {
        get { af.asBytes()[0] }
        set { af = UInt16(bytes: [newValue, a])! }
    }
    
    private var b: UInt8 {
        get { bc.asBytes()[1] }
        set { bc = UInt16(bytes: [c, newValue])! }
    }
    private var c: UInt8 {
        get { bc.asBytes()[0] }
        set { bc = UInt16(bytes: [newValue, b])! }
    }
    
    private var d: UInt8 {
        get { de.asBytes()[1] }
        set { de = UInt16(bytes: [e, newValue])! }
    }
    private var e: UInt8 {
        get { de.asBytes()[0] }
        set { de = UInt16(bytes: [newValue, d])! }
    }
    
    private var h: UInt8 {
        get { hl.asBytes()[1] }
        set { hl = UInt16(bytes: [l, newValue])! }
    }
    private var l: UInt8 {
        get { hl.asBytes()[0] }
        set { hl = UInt16(bytes: [newValue, h])! }
    }
    
    // Register Flags
    private var zFlag: Bool {
        get { f.checkBit(7) }
        set { newValue ? f.setBit(7) : f.clearBit(7) }
    }
    
    private var nFlag: Bool {
        get { f.checkBit(6) }
        set { newValue ? f.setBit(6) : f.clearBit(6) }
    }
    
    private var hFlag: Bool {
        get { f.checkBit(5) }
        set { newValue ? f.setBit(5) : f.clearBit(5) }
    }
    
    private var cFlag: Bool {
        get { f.checkBit(4) }
        set { newValue ? f.setBit(4) : f.clearBit(4) }
    }
    
    // Other Flags
    private var imeFlag = false // Interrupt Master Enable
    private var haltFlag = false
    private var stopFlag = false // TODO: Figure out when this should be reset.
    
    /// Execute the next instruction and returns the number of cycles it took.
    func executeInstruction() -> Int {
        
        print("--- PC: \(pc.hexString)")
        let opcode = fetchNextByte()
        
        if opcode == 0xCB {
            print("Byte was 0xCB")
            return execute16BitInstruction()
        } else {
            return execute8BitInstruction(opcode: opcode)
        }
    }
    
    func handleInterrupts() {
        if imeFlag { // Is master interrupt enable flag set?
            if let interruptAddress = MMU.shared.checkForInterrupt() {
                imeFlag = false
                _ = pushOntoStack(address: pc)
                pc = interruptAddress
            }
        }
    }
    
    private func fetchNextByte() -> UInt8 {
        let byte = MMU.shared.readValue(address: pc)
        pc &+= 1
        return byte
    }
    
    private func fetchNextShort() -> UInt16 {
        return UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
    }
    
    private func fetchByteAtNextAddress() -> UInt8 {
        return MMU.shared.readValue(address: fetchNextShort())
    }
}

// MARK: - 8-bit Instructions

extension CPU {
    
    /// Execute the instruction from the opcode and returns the number of cycles it took.
    private func execute8BitInstruction(opcode: UInt8) -> Int {
        print("Excuting 8-Bit Instruction: \(opcode.hexString)")
        switch opcode {
        case 0x00: return noOp()
        case 0x01: return loadImmediateShortIntoPair(&bc)
        case 0x02: return loadRegisterIntoAddress(address: bc, register: a)
        case 0x03: return incrementPair(&bc)
        case 0x04: return incrementRegister(&b)
        case 0x05: return decrementRegister(&b)
        case 0x06: return loadImmediateByteIntoRegister(&b)
        case 0x07: return rotateALeftWithCarry()
        case 0x08: return loadSPIntoAddress()
        case 0x09: return addToHL(bc)
        case 0x0A: return loadValueIntoRegister(register: &a, address: bc)
        case 0x0B: return decrementPair(&bc)
        case 0x0C: return incrementRegister(&c)
        case 0x0D: return decrementRegister(&c)
        case 0x0E: return loadImmediateByteIntoRegister(&c)
        case 0x0F: return rotateARightWithCarry()
            
        case 0x10: return stop()
        case 0x11: return loadImmediateShortIntoPair(&de)
        case 0x12: return loadRegisterIntoAddress(address: de, register: a)
        case 0x13: return incrementPair(&de)
        case 0x14: return incrementRegister(&d)
        case 0x15: return decrementRegister(&d)
        case 0x16: return loadImmediateByteIntoRegister(&d)
        case 0x17: return rotateALeftThroughCarry()
        case 0x18: return unconditionalRelativeJump()
        case 0x19: return addToHL(de)
        case 0x1A: return loadValueIntoRegister(register: &a, address: de)
        case 0x1B: return decrementPair(&de)
        case 0x1C: return incrementRegister(&e)
        case 0x1D: return decrementRegister(&e)
        case 0x1E: return loadImmediateByteIntoRegister(&e)
        case 0x1F: return rotateARightThroughCarry()
            
        case 0x20: return relativeJumpIfZFlagCleared()
        case 0x21: return loadImmediateShortIntoPair(&hl)
        case 0x22: return loadRegisterIntoAddress(address: hl, register: a, hlOperation: .increment)
        case 0x23: return incrementPair(&hl)
        case 0x24: return incrementRegister(&h)
        case 0x25: return decrementRegister(&h)
        case 0x26: return loadImmediateByteIntoRegister(&h)
        case 0x27: return decimalAdjustAfterAddition()
        case 0x28: return relativeJumpIfZFlagSet()
        case 0x29: return addToHL(hl)
        case 0x2A: return loadValueIntoRegister(register: &a, address: hl, hlOperation: .increment)
        case 0x2B: return decrementPair(&hl)
        case 0x2C: return incrementRegister(&l)
        case 0x2D: return decrementRegister(&l)
        case 0x2E: return loadImmediateByteIntoRegister(&l)
        case 0x2F: return flipBitsInA()
            
        case 0x30: return relativeJumpIfCFlagCleared()
        case 0x31: return loadImmediateShortIntoPair(&sp)
        case 0x32: return loadRegisterIntoAddress(address: hl, register: a, hlOperation: .decrement)
        case 0x33: return incrementPair(&sp)
        case 0x34: return incrementValue(address: hl)
        case 0x35: return decrementValue(address: hl)
        case 0x36: return loadImmediateByteIntoAddress(hl)
        case 0x37: return setCFlag()
        case 0x38: return relativeJumpIfCFlagSet()
        case 0x39: return addToHL(sp)
        case 0x3A: return loadValueIntoRegister(register: &a, address: hl, hlOperation: .decrement)
        case 0x3B: return decrementPair(&sp)
        case 0x3C: return incrementRegister(&a)
        case 0x3D: return decrementRegister(&a)
        case 0x3E: return loadImmediateByteIntoRegister(&a)
        case 0x3F: return flipCFlag()
            
        case 0x40: return loadByteIntoRegister(lhs: &b, rhs: b)
        case 0x41: return loadByteIntoRegister(lhs: &b, rhs: c)
        case 0x42: return loadByteIntoRegister(lhs: &b, rhs: d)
        case 0x43: return loadByteIntoRegister(lhs: &b, rhs: e)
        case 0x44: return loadByteIntoRegister(lhs: &b, rhs: h)
        case 0x45: return loadByteIntoRegister(lhs: &b, rhs: l)
        case 0x46: return loadValueIntoRegister(register: &b, address: hl)
        case 0x47: return loadByteIntoRegister(lhs: &b, rhs: a)
        case 0x48: return loadByteIntoRegister(lhs: &c, rhs: b)
        case 0x49: return loadByteIntoRegister(lhs: &c, rhs: c)
        case 0x4A: return loadByteIntoRegister(lhs: &c, rhs: d)
        case 0x4B: return loadByteIntoRegister(lhs: &c, rhs: e)
        case 0x4C: return loadByteIntoRegister(lhs: &c, rhs: h)
        case 0x4D: return loadByteIntoRegister(lhs: &c, rhs: l)
        case 0x4E: return loadValueIntoRegister(register: &c, address: hl)
        case 0x4F: return loadByteIntoRegister(lhs: &c, rhs: a)
            
        case 0x50: return loadByteIntoRegister(lhs: &d, rhs: b)
        case 0x51: return loadByteIntoRegister(lhs: &d, rhs: c)
        case 0x52: return loadByteIntoRegister(lhs: &d, rhs: d)
        case 0x53: return loadByteIntoRegister(lhs: &d, rhs: e)
        case 0x54: return loadByteIntoRegister(lhs: &d, rhs: h)
        case 0x55: return loadByteIntoRegister(lhs: &d, rhs: l)
        case 0x56: return loadValueIntoRegister(register: &d, address: hl)
        case 0x57: return loadByteIntoRegister(lhs: &d, rhs: a)
        case 0x58: return loadByteIntoRegister(lhs: &e, rhs: b)
        case 0x59: return loadByteIntoRegister(lhs: &e, rhs: c)
        case 0x5A: return loadByteIntoRegister(lhs: &e, rhs: d)
        case 0x5B: return loadByteIntoRegister(lhs: &e, rhs: e)
        case 0x5C: return loadByteIntoRegister(lhs: &e, rhs: h)
        case 0x5D: return loadByteIntoRegister(lhs: &e, rhs: l)
        case 0x5E: return loadValueIntoRegister(register: &e, address: hl)
        case 0x5F: return loadByteIntoRegister(lhs: &e, rhs: a)
            
        case 0x60: return loadByteIntoRegister(lhs: &h, rhs: b)
        case 0x61: return loadByteIntoRegister(lhs: &h, rhs: c)
        case 0x62: return loadByteIntoRegister(lhs: &h, rhs: d)
        case 0x63: return loadByteIntoRegister(lhs: &h, rhs: e)
        case 0x64: return loadByteIntoRegister(lhs: &h, rhs: h)
        case 0x65: return loadByteIntoRegister(lhs: &h, rhs: l)
        case 0x66: return loadValueIntoRegister(register: &h, address: hl)
        case 0x67: return loadByteIntoRegister(lhs: &h, rhs: a)
        case 0x68: return loadByteIntoRegister(lhs: &l, rhs: b)
        case 0x69: return loadByteIntoRegister(lhs: &l, rhs: c)
        case 0x6A: return loadByteIntoRegister(lhs: &l, rhs: d)
        case 0x6B: return loadByteIntoRegister(lhs: &l, rhs: e)
        case 0x6C: return loadByteIntoRegister(lhs: &l, rhs: h)
        case 0x6D: return loadByteIntoRegister(lhs: &l, rhs: l)
        case 0x6E: return loadValueIntoRegister(register: &l, address: hl)
        case 0x6F: return loadByteIntoRegister(lhs: &l, rhs: a)
            
        case 0x70: return loadRegisterIntoAddress(address: hl, register: b)
        case 0x71: return loadRegisterIntoAddress(address: hl, register: c)
        case 0x72: return loadRegisterIntoAddress(address: hl, register: d)
        case 0x73: return loadRegisterIntoAddress(address: hl, register: e)
        case 0x74: return loadRegisterIntoAddress(address: hl, register: h)
        case 0x75: return loadRegisterIntoAddress(address: hl, register: l)
        case 0x76: return halt()
        case 0x77: return loadRegisterIntoAddress(address: hl, register: a)
        case 0x78: return loadByteIntoRegister(lhs: &a, rhs: b)
        case 0x79: return loadByteIntoRegister(lhs: &a, rhs: c)
        case 0x7A: return loadByteIntoRegister(lhs: &a, rhs: d)
        case 0x7B: return loadByteIntoRegister(lhs: &a, rhs: e)
        case 0x7C: return loadByteIntoRegister(lhs: &a, rhs: h)
        case 0x7D: return loadByteIntoRegister(lhs: &a, rhs: l)
        case 0x7E: return loadValueIntoRegister(register: &a, address: hl)
        case 0x7F: return loadByteIntoRegister(lhs: &a, rhs: a)
            
        case 0x80: return addOperation(lhs: &a, rhs: b)
        case 0x81: return addOperation(lhs: &a, rhs: c)
        case 0x82: return addOperation(lhs: &a, rhs: d)
        case 0x83: return addOperation(lhs: &a, rhs: e)
        case 0x84: return addOperation(lhs: &a, rhs: h)
        case 0x85: return addOperation(lhs: &a, rhs: l)
        case 0x86: return addOperation(lhs: &a, address: hl)
        case 0x87: return addOperation(lhs: &a, rhs: a)
        case 0x88: return addWithCarryOperation(lhs: &a, rhs: b)
        case 0x89: return addWithCarryOperation(lhs: &a, rhs: c)
        case 0x8A: return addWithCarryOperation(lhs: &a, rhs: d)
        case 0x8B: return addWithCarryOperation(lhs: &a, rhs: e)
        case 0x8C: return addWithCarryOperation(lhs: &a, rhs: h)
        case 0x8D: return addWithCarryOperation(lhs: &a, rhs: l)
        case 0x8E: return addWithCarryOperation(lhs: &a, address: hl)
        case 0x8F: return addWithCarryOperation(lhs: &a, rhs: a)
            
        case 0x90: return subtractOperation(lhs: &a, rhs: b)
        case 0x91: return subtractOperation(lhs: &a, rhs: c)
        case 0x92: return subtractOperation(lhs: &a, rhs: d)
        case 0x93: return subtractOperation(lhs: &a, rhs: e)
        case 0x94: return subtractOperation(lhs: &a, rhs: h)
        case 0x95: return subtractOperation(lhs: &a, rhs: l)
        case 0x96: return subtractOperation(lhs: &a, address: hl)
        case 0x97: return subtractOperation(lhs: &a, rhs: a)
        case 0x98: return subtractWithCarryOperation(lhs: &a, rhs: b)
        case 0x99: return subtractWithCarryOperation(lhs: &a, rhs: c)
        case 0x9A: return subtractWithCarryOperation(lhs: &a, rhs: d)
        case 0x9B: return subtractWithCarryOperation(lhs: &a, rhs: e)
        case 0x9C: return subtractWithCarryOperation(lhs: &a, rhs: h)
        case 0x9D: return subtractWithCarryOperation(lhs: &a, rhs: l)
        case 0x9E: return subtractWithCarryOperation(lhs: &a, address: hl)
        case 0x9F: return subtractWithCarryOperation(lhs: &a, rhs: a)
            
        case 0xA0: return logicalAndOperation(lhs: &a, rhs: b)
        case 0xA1: return logicalAndOperation(lhs: &a, rhs: c)
        case 0xA2: return logicalAndOperation(lhs: &a, rhs: d)
        case 0xA3: return logicalAndOperation(lhs: &a, rhs: e)
        case 0xA4: return logicalAndOperation(lhs: &a, rhs: h)
        case 0xA5: return logicalAndOperation(lhs: &a, rhs: l)
        case 0xA6: return logicalAndOperation(lhs: &a, address: hl)
        case 0xA7: return logicalAndOperation(lhs: &a, rhs: a)
        case 0xA8: return logicalXorOperation(lhs: &a, rhs: b)
        case 0xA9: return logicalXorOperation(lhs: &a, rhs: c)
        case 0xAA: return logicalXorOperation(lhs: &a, rhs: d)
        case 0xAB: return logicalXorOperation(lhs: &a, rhs: e)
        case 0xAC: return logicalXorOperation(lhs: &a, rhs: h)
        case 0xAD: return logicalXorOperation(lhs: &a, rhs: l)
        case 0xAE: return logicalXorOperation(lhs: &a, address: hl)
        case 0xAF: return logicalXorOperation(lhs: &a, rhs: a)
            
        case 0xB0: return logicalOrOperation(lhs: &a, rhs: b)
        case 0xB1: return logicalOrOperation(lhs: &a, rhs: c)
        case 0xB2: return logicalOrOperation(lhs: &a, rhs: d)
        case 0xB3: return logicalOrOperation(lhs: &a, rhs: e)
        case 0xB4: return logicalOrOperation(lhs: &a, rhs: h)
        case 0xB5: return logicalOrOperation(lhs: &a, rhs: l)
        case 0xB6: return logicalOrOperation(lhs: &a, address: hl)
        case 0xB7: return logicalOrOperation(lhs: &a, rhs: a)
        case 0xB8: return compare(lhs: a, rhs: b)
        case 0xB9: return compare(lhs: a, rhs: c)
        case 0xBA: return compare(lhs: a, rhs: d)
        case 0xBB: return compare(lhs: a, rhs: e)
        case 0xBC: return compare(lhs: a, rhs: h)
        case 0xBD: return compare(lhs: a, rhs: l)
        case 0xBE: return compare(lhs: a, address: hl)
        case 0xBF: return compare(lhs: a, rhs: a)
            
        case 0xC0: return returnControl(condition: !zFlag)
        case 0xC1: return popStack(into: &bc)
        case 0xC2: return jumpToNextByteAddress(condition: !zFlag)
        case 0xC3: return jumpToNextByteAddress()
        case 0xC4: return call(condition: !zFlag)
        case 0xC5: return pushOntoStack(address: bc)
        case 0xC6: return addNextByteToA()
        case 0xC7: return restart(offset: 0)
        case 0xC8: return returnControl(condition: zFlag)
        case 0xC9: return returnControl()
        case 0xCA: return jumpToNextByteAddress(condition: zFlag)
        case 0xCB: break
        case 0xCC: return call(condition: zFlag)
        case 0xCD: return call()
        case 0xCE: return addNextByteWithCarryToA()
        case 0xCF: return restart(offset: 1)
            
        case 0xD0: return returnControl(condition: !cFlag)
        case 0xD1: return popStack(into: &de)
        case 0xD2: return jumpToNextByteAddress(condition: !cFlag)
        case 0xD3: break
        case 0xD4: return call(condition: !cFlag)
        case 0xD5: return pushOntoStack(address: de)
        case 0xD6: return subtractNextByteFromA()
        case 0xD7: return restart(offset: 2)
        case 0xD8: return returnControl(condition: cFlag)
        case 0xD9: return returnControlEnablingInterrupt()
        case 0xDA: return jumpToNextByteAddress(condition: cFlag)
        case 0xDB: break
        case 0xDC: return call(condition: cFlag)
        case 0xDD: break
        case 0xDE: return subtractNextByteWithCarryFromA()
        case 0xDF: return restart(offset: 3)
            
        case 0xE0: return highPageLoadAIntoNextByteAddress()
        case 0xE1: return popStack(into: &hl)
        case 0xE2: return highPageLoadAIntoAddressC()
        case 0xE3: break
        case 0xE4: break
        case 0xE5: return pushOntoStack(address: hl)
        case 0xE6: return logicalAndNextByteToA()
        case 0xE7: return restart(offset: 4)
        case 0xE8: return addNextByteToSP()
        case 0xE9: return jump(address: hl)
        case 0xEA: return loadAIntoShortAddress()
        case 0xEB: break
        case 0xEC: break
        case 0xED: break
        case 0xEE: return logicalXorByteToA()
        case 0xEF: return restart(offset: 5)
            
        case 0xF0: return highPageLoadNextByteAddressIntoA()
        case 0xF1: return popStack(into: &af)
        case 0xF2: return highPageLoadAddressCIntoA()
        case 0xF3: return disableInterruptHandling()
        case 0xF4: break
        case 0xF5: return pushOntoStack(address: af)
        case 0xF6: return logicalOrByteToA()
        case 0xF7: return restart(offset: 6)
        case 0xF8: return loadSPPlusByteIntoHL()
        case 0xF9: return loadHLIntoSP()
        case 0xFA: return loadShortAddressIntoA()
        case 0xFB: return scheduleInterruptHandling()
        case 0xFC: break
        case 0xFD: break
        case 0xFE: return compareByteToA()
        case 0xFF: return restart(offset: 7)
            
        default: fatalError("Encountered unknown 8-bit opcode: \(opcode).")
        }
        
        return 0 // No instruction for opcode.
    }
    
    /// 0x00
    private func noOp() -> Int {
        // No Operation
        return 1
    }
    
    /// 0x07
    private func rotateALeftWithCarry() -> Int {
        cFlag = a.checkBit(7)
        a = a.bitwiseLeftRotation(amount: 1)
        zFlag = false
        nFlag = false
        hFlag = false
        return 1
    }
    
    /// 0x08
    private func loadSPIntoAddress() -> Int {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        MMU.shared.writeValue(sp.asBytes()[0], address: address)
        MMU.shared.writeValue(sp.asBytes()[1], address: address+1)
        return 5
    }
    
    /// 0x0F
    private func rotateARightWithCarry() -> Int {
        cFlag = a.checkBit(0)
        a = a.bitwiseRightRotation(amount: 1)
        zFlag = false
        nFlag = false
        hFlag = false
        return 1
    }
    
    /// 0x10
    private func stop() -> Int {
        // Stop instruction is two bytes long, so we need to read the next byte as well.
        // 0x10, 0x00
        stopFlag = true
        guard fetchNextByte() == 0x00 else { fatalError("Second byte of STOP instruction was not 0x00.") }
        return 1
    }
    
    /// 0x17
    private func rotateALeftThroughCarry() -> Int {
        let previousCarry = cFlag
        cFlag = a.checkBit(7)
        a = a.bitwiseLeftRotation(amount: 1)
        previousCarry ? a.setBit(0) : a.clearBit(0)
        zFlag = false
        nFlag = false
        hFlag = false
        
        return 1
    }
    
    /// 0x18
    private func unconditionalRelativeJump() -> Int {
        relativeJump(byte: fetchNextByte())
        return 3
    }
    
    /// 0x1F
    private func rotateARightThroughCarry() -> Int {
        let previousCarry = cFlag
        cFlag = a.checkBit(0)
        a = a.bitwiseRightRotation(amount: 1)
        previousCarry ? a.setBit(7) : a.clearBit(7)
        zFlag = false
        nFlag = false
        hFlag = false
        
        return 1
    }
    
    /// 0x20
    private func relativeJumpIfZFlagCleared() -> Int {
        let operand = fetchNextByte()
        if !zFlag {
            relativeJump(byte: operand)
            return 3
        } else {
            return 2
        }
    }

    /// 0x27
    private func decimalAdjustAfterAddition() -> Int {
        // Refs:
        // https://ehaskins.com/2018-01-30%20Z80%20DAA/
        // https://binji.github.io/posts/pokegb/
        
        var bcdCorrection: UInt8 = 0
        var carry = false
        if (hFlag || (!nFlag && a.lowNibble > 0x9)) {
            bcdCorrection |= 0x6
        }
        if (cFlag || (!nFlag && a > 0x99)) {
            bcdCorrection |= 0x60
            carry = true
        }
        
        if nFlag {
            a &-= bcdCorrection
        } else {
            a &+= bcdCorrection
        }
        
        zFlag = a == 0
        hFlag = false
        cFlag = carry
        
        return 1
    }
    
    /// 0x28
    private func relativeJumpIfZFlagSet() -> Int {
        let operand = fetchNextByte()
        if zFlag {
            relativeJump(byte: operand)
            return 3
        } else {
            return 2
        }
    }
    
    /// 0x2F
    private func flipBitsInA() -> Int {
        a = ~a
        nFlag = true
        hFlag = true
        
        return 1
    }
    
    /// 0x30
    private func relativeJumpIfCFlagCleared() -> Int {
        let operand = fetchNextByte()
        if !cFlag {
            relativeJump(byte: operand)
            return 3
        } else {
            return 2
        }
    }
    
    /// 0x37
    private func setCFlag() -> Int {
        cFlag = true
        // Also need to clear n and h flags
        nFlag = false
        hFlag = false
        
        return 1
    }
    
    /// 0x38
    private func relativeJumpIfCFlagSet() -> Int {
        let operand = fetchNextByte()
        if cFlag {
            relativeJump(byte: operand)
            return 3
        } else {
            return 2
        }
    }
    
    /// 0x3F
    private func flipCFlag() -> Int {
        cFlag.toggle()
        // Also need to clear n and h flags
        nFlag = false
        hFlag = false
        
        return 1
    }
    
    /// 0x76
    private func halt() -> Int {
        haltFlag = true
        // TODO: This is pretty complicated, I think.
        return 1
    }
    
    // MARK: - Load Operations
    
    // 0x01, 0x11, 0x21, 0x31
    private func loadImmediateShortIntoPair(_ pair: inout UInt16) -> Int {
        let value = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        pair = value
        return 3
    }
    
    // 0xF9
    private func loadHLIntoSP() -> Int {
        sp = hl
        return 2
    }
    
    // 0x02, 0x12, 0x22, 0x32, 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x77
    private func loadRegisterIntoAddress(address: UInt16, register: UInt8, hlOperation: HLOperation = .nothing) -> Int {
        MMU.shared.writeValue(a, address: address)
        executeHLOperation(hlOperation)
        return 2
    }
    
    // 0x36
    private func loadImmediateByteIntoAddress(_ address: UInt16) -> Int {
        let value = fetchNextByte()
        MMU.shared.writeValue(value, address: address)
        return 3
    }
    
    // 0x06, 0x16, 0x26, 0x0E, 0x1E, 0x2E, 0x3E
    private func loadImmediateByteIntoRegister(_ register: inout UInt8) -> Int {
        let value = fetchNextByte()
        register = value
        return 2
    }
    
    // 0x0A, 0x1A, 0x2A, 0x3A, 0x46, 0x56, 0x66, 0x4E, 0x5E, 0x6E
    private func loadValueIntoRegister(register: inout UInt8, address: UInt16, hlOperation: HLOperation = .nothing) -> Int {
        register = MMU.shared.readValue(address: address)
        executeHLOperation(hlOperation)
        return 2
    }
    
    // 0x40 - 0x45, 0x47 - 0x4D, 0x4F
    // 0x50 - 0x55, 0x57 - 0x5D, 0x5F
    // 0x60 - 0x65, 0x67 - 0x6D, 0x6F
    // 0x78 - 0x7D, 0x7F
    private func loadByteIntoRegister(lhs: inout UInt8, rhs: UInt8) -> Int {
        lhs = rhs
        return 1
    }
    
    // 0xE0
    private func highPageLoadAIntoNextByteAddress() -> Int {
        let lowerByte = fetchNextByte()
        let address = UInt16(bytes: [lowerByte, 0xFF])!
        MMU.shared.writeValue(a, address: address)
        return 3
    }
    
    // 0xF0
    private func highPageLoadNextByteAddressIntoA() -> Int {
        let lowerByte = fetchNextByte()
        let address = UInt16(bytes: [lowerByte, 0xFF])!
        a = MMU.shared.readValue(address: address)
        return 3
    }
    
    // 0xE2
    private func highPageLoadAIntoAddressC() -> Int {
        let address = UInt16(bytes: [c, 0xFF])!
        MMU.shared.writeValue(a, address: address)
        return 2
    }
    
    // 0xF2
    private func highPageLoadAddressCIntoA() -> Int {
        let address = UInt16(bytes: [c, 0xFF])!
        a = MMU.shared.readValue(address: address)
        return 2
    }
    
    // 0xEA
    private func loadAIntoShortAddress() -> Int {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        MMU.shared.writeValue(a, address: address)
        return 4
    }
    
    // 0xEA, 0xFA
    private func loadShortAddressIntoA() -> Int {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        a = MMU.shared.readValue(address: address)
        return 4
    }
    
    // 0xF8
    private func loadSPPlusByteIntoHL() -> Int {
        let signedByte = Int8(bitPattern: fetchNextByte())
        hl = addOperation(lhs: sp, rhs: signedByte)
        return 3
    }
    
    // MARK: - Increment/Decrement Operations
    
    // 0x03, 0x13, 0x23, 0x33
    private func incrementPair(_ pair: inout UInt16) -> Int {
        pair &+= 1
        return 2
    }
    
    // 0x0B, 0x1B, 0x2B, 0x3B
    private func decrementPair(_ pair: inout UInt16) -> Int {
        pair &-= 1
        return 2
    }
    
    // 0x04, 0x14, 0x24, 0x0C, 0x1C, 0x2C, 0x3C
    private func incrementRegister(_ register: inout UInt8) -> Int {
        register = incrementOperation(register)
        return 1
    }
    
    // 0x05, 0x15, 0x25, 0x0D, 0x1D, 0x2D, 0x3D
    private func decrementRegister(_ register: inout UInt8) -> Int {
        register = decrementOperation(register)
        return 1
    }
    
    /// 0x34
    private func incrementValue(address: UInt16) -> Int {
        let value = MMU.shared.readValue(address: address)
        let incrementedValue = incrementOperation(value)
        MMU.shared.writeValue(incrementedValue, address: address)
        return 3
    }
    
    /// 0x35
    private func decrementValue(address: UInt16) -> Int {
        let value = MMU.shared.readValue(address: address)
        let decrementedValue = decrementOperation(value)
        MMU.shared.writeValue(decrementedValue, address: address)
        return 3
    }
    
    // MARK: - Arithmetical Operations

    // 0xE8
    private func addNextByteToSP() -> Int {
        let signedByte = Int8(bitPattern: fetchNextByte())
        sp = addOperation(lhs: sp, rhs: signedByte)
        return 4
    }
    
    // 0xC6
    private func addNextByteToA() -> Int {
        _ = addOperation(lhs: &a, rhs: fetchNextByte())
        return 2
    }
    
    // 0xCE
    private func addNextByteWithCarryToA() -> Int {
        let carryBit: UInt8 = cFlag ? 1 : 0
        let byte = fetchNextByte() &+ carryBit
        _ = addOperation(lhs: &a, rhs: byte)
        return 2
    }
        
    // 0x09, 0x19, 0x29, 0x39
    private func addToHL(_ value: UInt16) -> Int {
        let oldZflag = zFlag
        // Ref: https://stackoverflow.com/a/57981912
        _ = addOperation(lhs: &l, rhs: value.asBytes()[0])
        _ = addWithCarryOperation(lhs: &h, rhs: value.asBytes()[1])
        
        // Apparently the Z Flag is unnaffected by this operation, so we set it back to it's original value
        // from before the two operations.
        // That's weird though since it kinda goes against what the reference above suggests happens.
        zFlag = oldZflag
        return 2
    }
    
    
    // 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x87
    private func addOperation(lhs: inout UInt8, rhs: UInt8) -> Int {
        let (value, carry) = lhs.addingReportingOverflow(rhs)
        let (_, halfCarry) = lhs.addingReportingHalfCarry(rhs)
        
        lhs = value
        
        zFlag = value == 0
        nFlag = false
        hFlag = halfCarry
        cFlag = carry
        
        return 1
    }
    
    // 0x86
    private func addOperation(lhs: inout UInt8, address: UInt16) -> Int {
        let rhs = MMU.shared.readValue(address: address)
        _ = addOperation(lhs: &lhs, rhs: rhs)
        return 2
    }
    
    // 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8F
    private func addWithCarryOperation(lhs: inout UInt8, rhs: UInt8) -> Int {
        let carryBit: UInt8 = cFlag ? 1 : 0
        let value = rhs &+ carryBit
        return addOperation(lhs: &lhs, rhs: value)
    }
    
    // 0x8E
    private func addWithCarryOperation(lhs: inout UInt8, address: UInt16) -> Int {
        let rhs = MMU.shared.readValue(address: address)
        _ = addWithCarryOperation(lhs: &lhs, rhs: rhs)
        return 2
    }
    
    // 0xD6
    private func subtractNextByteFromA() -> Int {
        _ = subtractOperation(lhs: &a, rhs: fetchNextByte())
        return 2
    }
    
    // 0xDE
    private func subtractNextByteWithCarryFromA() -> Int {
        let carryBit: UInt8 = cFlag ? 1 : 0
        let byte = fetchNextByte() &+ carryBit
        _ = subtractOperation(lhs: &a, rhs: byte)
        return 2
    }
    
    // 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x97
    private func subtractOperation(lhs: inout UInt8, rhs: UInt8) -> Int {
        let (value, carry) = lhs.subtractingReportingOverflow(rhs)
        let (_, halfCarry) = lhs.subtractingReportingHalfCarry(rhs)
        
        lhs = value
        
        zFlag = value == 0
        nFlag = true
        hFlag = halfCarry
        cFlag = carry
        
        return 1
    }
    
    // 0x96
    private func subtractOperation(lhs: inout UInt8, address: UInt16) -> Int {
        let rhs = MMU.shared.readValue(address: address)
        _ = subtractOperation(lhs: &lhs, rhs: rhs)
        return 2
    }
    
    // 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9F
    private func subtractWithCarryOperation(lhs: inout UInt8, rhs: UInt8) -> Int {
        let carryBit: UInt8 = cFlag ? 1 : 0
        let value = rhs &+ carryBit
        return subtractOperation(lhs: &lhs, rhs: value)
    }
    
    // 0x9E
    private func subtractWithCarryOperation(lhs: inout UInt8, address: UInt16) -> Int {
        let rhs = MMU.shared.readValue(address: address)
        _ = subtractWithCarryOperation(lhs: &lhs, rhs: rhs)
        return 2
    }
    
    // MARK: - Logical Operations
    
    // 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0xA7
    private func logicalAndOperation(lhs: inout UInt8, rhs: UInt8) -> Int {
        let value = lhs & rhs
        
        lhs = value
        
        zFlag = value == 0
        nFlag = false
        hFlag = true
        cFlag = false
        
        return 1
    }
    
    // 0xA6
    private func logicalAndOperation(lhs: inout UInt8, address: UInt16) -> Int {
        let rhs = MMU.shared.readValue(address: address)
        _ = logicalAndOperation(lhs: &lhs, rhs: rhs)
        return 2
    }
    
    // 0xE6
    private func logicalAndNextByteToA() -> Int {
        let byte = fetchNextByte()
        _ = logicalAndOperation(lhs: &a, rhs: byte)
        return 2
    }
    
    // 0xA8, 0xA9, 0xAA, 0xAB, 0xAC, 0xAD, 0xAF
    private func logicalXorOperation(lhs: inout UInt8, rhs: UInt8) -> Int {
        let value = lhs ^ rhs
        
        lhs = value
        
        zFlag = value == 0
        nFlag = false
        hFlag = false
        cFlag = false
        
        return 1
    }
    
    // 0xAE
    private func logicalXorOperation(lhs: inout UInt8, address: UInt16) -> Int {
        let rhs = MMU.shared.readValue(address: address)
        _ = logicalXorOperation(lhs: &lhs, rhs: rhs)
        return 2
    }
    
    // 0xEE
    private func logicalXorByteToA() -> Int {
        let byte = fetchNextByte()
        _ = logicalXorOperation(lhs: &a, rhs: byte)
        return 2
    }
    
    // 0xB0, 0xB1, 0xB2, 0xB3, 0xB4, 0xB5, 0xB7
    private func logicalOrOperation(lhs: inout UInt8, rhs: UInt8) -> Int {
        let value = lhs | rhs
        
        lhs = value
        
        zFlag = value == 0
        nFlag = false
        hFlag = false
        cFlag = false
        
        return 1
    }
    
    // 0xB6
    private func logicalOrOperation(lhs: inout UInt8, address: UInt16) -> Int {
        let rhs = MMU.shared.readValue(address: address)
        _ = logicalOrOperation(lhs: &lhs, rhs: rhs)
        return 2
    }
    
    // 0xF6
    private func logicalOrByteToA() -> Int {
        let byte = fetchNextByte()
        _ = logicalOrOperation(lhs: &a, rhs: byte)
        return 2
    }
    
    // 0xB8, 0xB9, 0xBA, 0xBB, 0xBC, 0xBD, 0xBF
    private func compare(lhs: UInt8, rhs: UInt8) -> Int {
        let (comparison, carry) = lhs.subtractingReportingOverflow(rhs)
        let (_, halfCarry) = lhs.subtractingReportingHalfCarry(rhs)
        
        zFlag = comparison == 0
        nFlag = true
        hFlag = halfCarry
        cFlag = carry
        
        return 1
    }
    
    // 0xBE
    private func compare(lhs: UInt8, address: UInt16) -> Int {
        let rhs = MMU.shared.readValue(address: address)
        _ = compare(lhs: lhs, rhs: rhs)
        return 2
    }
    
    // 0xFE
    private func compareByteToA() -> Int {
        let byte = fetchNextByte()
        _ = compare(lhs: a, rhs: byte)
        return 2
    }
    
    // MARK: - Miscellaneous Operations
    
    // 0xC0, 0xC8, 0xD0, 0xD8
    private func returnControl(condition: Bool) -> Int {
        if condition {
            pc = popStack()
            return 5
        } else {
            return 2
        }
    }
    
    // 0xC9
    private func returnControl() -> Int {
        pc = popStack()
        return 4
    }
    
    // 0xD9
    private func returnControlEnablingInterrupt() -> Int {
        pc = popStack()
        imeFlag = true
        return 4
    }
    
    // 0xC1, 0xD1, 0xE1, 0xF1
    private func popStack(into pair: inout UInt16) -> Int {
        pair = popStack()
        return 3
    }
    
    // 0xC5, 0xD5, 0xE5, 0xF5
    private func pushOntoStack(address: UInt16) -> Int {
        let bytes = address.asBytes()
        let lowerByte = bytes[0]
        let upperByte = bytes[1]
        
        sp &-= 1
        MMU.shared.writeValue(upperByte, address: sp)
        sp &-= 1
        MMU.shared.writeValue(lowerByte, address: sp)
        
        return 4
    }
    
    // 0xC2, 0xC3, 0xCA, 0xD2, 0xDA
    private func jumpToNextByteAddress(condition: Bool = true) -> Int {
        let address = fetchNextShort()
        if condition {
            pc = address
            return 4
        } else {
            return 3
        }
    }
    
    // 0xE9
    private func jump(address: UInt16) -> Int {
        pc = address
        return 1
    }
    
    // 0xC4, 0xCC, 0xCD, 0xD4, 0xDC
    private func call(condition: Bool = true) -> Int {
        let address = fetchNextShort()
        if condition {
            _ = pushOntoStack(address: pc)
            pc = address
            return 6
        } else {
            return 3
        }
    }
    
    // 0xC7, 0xD7, 0xE7, 0xF7, 0xCF, 0xDF, 0xEF, 0xFF
    private func restart(offset: Int) -> Int {
        _ = pushOntoStack(address: pc)
        let address: UInt16 = 0x08 * UInt16(offset)
        pc = address
        return 4
    }
    
    // 0xF3
    private func disableInterruptHandling() -> Int {
        imeFlag = false
        return 1
    }
    
    // 0xFB
    private func scheduleInterruptHandling() -> Int {
        imeFlag = true
        // TODO: Invesitgate this more
        return 1
    }
}

// MARK: - 16-bit Instructions (Opcodes with 0xCB prefix)

extension CPU {
    
    private func execute16BitInstruction() -> Int {
        let opcode = fetchNextByte()
        print("Executing 8-Bit Instruction: \(opcode.hexString)")
        let registerId = opcode.lowNibble
        let usesHL = (registerId == 0x6) || (registerId == 0xE)
        
        switch opcode {
        
        case 0x00...0x07:
            rotateLeftWithCarry(opcode: opcode)
            return usesHL ? 4 : 2
            
        case 0x08...0x0F: // Rotate right with carry
            rotateRightWithCarry(opcode: opcode)
            return usesHL ? 4 : 2
            
        case 0x10...0x17: // Rotate left
            rotateLeft(opcode: opcode)
            return usesHL ? 4 : 2
            
        case 0x18...0x1F: // Rotate right
            rotateRight(opcode: opcode)
            return usesHL ? 4 : 2
            
        case 0x20...0x27: // Shift left arithmetic
            shiftLeftArithmetic(opcode: opcode)
            return usesHL ? 4 : 2
            
        case 0x28...0x2F: // Shift right arithmetic
            shiftRightArithmetic(opcode: opcode)
            return usesHL ? 4 : 2
            
        case 0x30...0x37: // Swap nibbles
            swapNibbles(opcode: opcode)
            return usesHL ? 4 : 2
            
        case 0x38...0x3F: // Shift right logical
            shiftRightLogical(opcode: opcode)
            return usesHL ? 4 : 2
            
        case 0x40...0x7F: // Check bit
            checkBit(opcode: opcode)
            return usesHL ? 3 : 2
            
        case 0x80...0xBF: // Reset bit
            resetBit(opcode: opcode)
            return usesHL ? 4 : 2
            
        case 0xC0...0xFF: // Set bit
            setBit(opcode: opcode)
            return usesHL ? 4 : 2
            
        default: fatalError("Unhandled opcode found. Got \(opcode).")
        }
    }
}

// MARK: - Convenience

extension CPU {
    
    /// Parts of the opcode tables are organised in a way where the high nibble is the function
    /// and the low nibble is the register parameter.
    private func getRegisterByte(opcode: UInt8) -> UInt8 {
        switch opcode.lowNibble {
        case 0x0, 0x8: return b
        case 0x1, 0x9: return c
        case 0x2, 0xA: return d
        case 0x3, 0xB: return e
        case 0x4, 0xC: return h
        case 0x5, 0xD: return l
        case 0x6, 0xE: return MMU.shared.readValue(address: hl)
        case 0x7, 0xF: return a
        default: fatalError("Failed to get byte register for opcode: \(opcode)")
        }
    }
    
    /// Parts of the opcode tables are organised in a way where the high nibble is the function
    /// and the low nibble is the register parameter.
    private func setRegisterValueForOpcode(_ opcode: UInt8, value: UInt8) {
        switch opcode.lowNibble {
        case 0x0, 0x8: b = value
        case 0x1, 0x9: c = value
        case 0x2, 0xA: d = value
        case 0x3, 0xB: e = value
        case 0x4, 0xC: h = value
        case 0x5, 0xD: l = value
        case 0x6, 0xE: MMU.shared.writeValue(value, address: hl)
        case 0x7, 0xF: a = value
        default: fatalError("Failed to set byte register for opcode: \(opcode)")
        }
    }
}

// MARK: - Arithmetic, Boolean Logic, and Control

extension CPU {
    
    private func popStack() -> UInt16 {
        let lowerByte = MMU.shared.readValue(address: sp)
        sp &+= 1
        let upperByte = MMU.shared.readValue(address: sp)
        sp &+= 1
        return UInt16(bytes: [lowerByte, upperByte])!
    }

    
    private func incrementOperation(_ value: UInt8) -> UInt8 {
        let (incrementedValue, halfCarry) = value.addingReportingHalfCarry(1)
        
        zFlag = incrementedValue == 0
        nFlag = false
        hFlag = halfCarry
        
        return incrementedValue
    }
    
    private func decrementOperation(_ value: UInt8) -> UInt8 {
        let (decrementedValue, halfCarry) = value.subtractingReportingHalfCarry(1)

        zFlag = decrementedValue == 0
        nFlag = true
        hFlag = halfCarry
        
        return decrementedValue
    }
    
    private func addOperation(lhs: UInt16, rhs: Int8) -> UInt16 {
        let isPositive = rhs >= 0
        let magnitude = rhs.magnitude
        
        let value: UInt16
        let halfCarryFlag: Bool
        let carryFlag: Bool
        if isPositive {
            let (lowerByte, carry) = lhs.asBytes()[0].addingReportingOverflow(magnitude)
            let (_, halfCarry) = lhs.asBytes()[0].addingReportingHalfCarry(magnitude)
            let carryBit: UInt8 = carry ? 1 : 0
            let upperByte = lhs.asBytes()[1] &+ carryBit
            
            value = UInt16(bytes: [lowerByte, upperByte])!
            halfCarryFlag = halfCarry
            carryFlag = carry
        } else {
            let (lowerByte, carry) = lhs.asBytes()[0].subtractingReportingOverflow(magnitude)
            let (_, halfCarry) = lhs.asBytes()[0].subtractingReportingHalfCarry(magnitude)
            let carryBit: UInt8 = carry ? 1 : 0
            let upperByte = lhs.asBytes()[1] &- carryBit
            
            value = UInt16(bytes: [lowerByte, upperByte])!
            halfCarryFlag = halfCarry
            carryFlag = carry
        }
        
        zFlag = false
        nFlag = false
        hFlag = halfCarryFlag
        cFlag = carryFlag
        return value
    }
    
    private func relativeJump(byte: UInt8) {
        let offset = Int8(bitPattern: byte)
        let offsetMagnitude = UInt16(offset.magnitude)
        
        let isPositive = offset >= 0
        if isPositive {
            pc &+= offsetMagnitude
        } else {
            pc &-= offsetMagnitude
        }
    }
}

// MARK: - HL Operation Convenience

extension CPU {
    
    // Some functions require the HL pair to be incremented or decremented after the instruction has been executed.
    // This is a convenience enum to allow us to not have to create custom functions just for the HL pair.
    // Maybe not the most intuitive way to do this, but it works.
    private enum HLOperation {
        case nothing
        case increment
        case decrement
    }
    
    private func executeHLOperation(_ operation: HLOperation) {
        switch operation {
        case .nothing: break
        case .increment: hl &+= 1
        case .decrement: hl &-= 1
        }
    }
}

extension CPU {
    
    private func rotateLeftWithCarry(opcode: UInt8) {
        let oldRegisterValue = getRegisterByte(opcode: opcode)
        let newRegisterValue = oldRegisterValue.bitwiseLeftRotation(amount: 1)
        
        setRegisterValueForOpcode(opcode, value: newRegisterValue)
        zFlag = newRegisterValue == 0
        nFlag = false
        hFlag = false
        cFlag = oldRegisterValue.checkBit(7)
    }
    
    private func rotateRightWithCarry(opcode: UInt8) {
        let oldRegisterValue = getRegisterByte(opcode: opcode)
        let newRegisterValue = oldRegisterValue.bitwiseRightRotation(amount: 1)
        
        setRegisterValueForOpcode(opcode, value: newRegisterValue)
        zFlag = newRegisterValue == 0
        nFlag = false
        hFlag = false
        cFlag = oldRegisterValue.checkBit(0)
    }
    
    private func rotateLeft(opcode: UInt8) {
        let oldRegisterValue = getRegisterByte(opcode: opcode)
        var newRegisterValue = oldRegisterValue.bitwiseLeftRotation(amount: 1)
        cFlag ? newRegisterValue.setBit(0) : newRegisterValue.clearBit(0)
        
        setRegisterValueForOpcode(opcode, value: newRegisterValue)
        zFlag = newRegisterValue == 0
        nFlag = false
        hFlag = false
        cFlag = oldRegisterValue.checkBit(7)
    }
    
    private func rotateRight(opcode: UInt8) {
        let oldRegisterValue = getRegisterByte(opcode: opcode)
        var newRegisterValue = oldRegisterValue.bitwiseRightRotation(amount: 1)
        cFlag ? newRegisterValue.setBit(7) : newRegisterValue.clearBit(7)
        
        setRegisterValueForOpcode(opcode, value: newRegisterValue)
        zFlag = newRegisterValue == 0
        nFlag = false
        hFlag = false
        cFlag = oldRegisterValue.checkBit(0)
    }
    

    private func shiftLeftArithmetic(opcode: UInt8) {
        let oldRegisterValue = getRegisterByte(opcode: opcode)
        let newRegisterValue = oldRegisterValue << 1
        
        setRegisterValueForOpcode(opcode, value: newRegisterValue)
        zFlag = newRegisterValue == 0
        nFlag = false
        hFlag = false
        cFlag = oldRegisterValue.checkBit(7)
    }
    
    private func shiftRightArithmetic(opcode: UInt8) {
        let oldRegisterValue = getRegisterByte(opcode: opcode)
        var newRegisterValue = oldRegisterValue >> 1
        oldRegisterValue.checkBit(7) ? newRegisterValue.setBit(7) : newRegisterValue.clearBit(7)
        
        setRegisterValueForOpcode(opcode, value: newRegisterValue)
        zFlag = newRegisterValue == 0
        nFlag = false
        hFlag = false
        cFlag = oldRegisterValue.checkBit(0)
    }
    
    private func swapNibbles(opcode: UInt8) {
        let oldRegisterValue = getRegisterByte(opcode: opcode)
        let newRegisterValue = (oldRegisterValue.lowNibble << 4) | oldRegisterValue.highNibble
        
        setRegisterValueForOpcode(opcode, value: newRegisterValue)
        zFlag = newRegisterValue == 0
        nFlag = false
        hFlag = false
        cFlag = false
    }
    
    private func shiftRightLogical(opcode: UInt8) {
        let oldRegisterValue = getRegisterByte(opcode: opcode)
        let newRegisterValue = oldRegisterValue >> 1
        
        setRegisterValueForOpcode(opcode, value: newRegisterValue)
        zFlag = newRegisterValue == 0
        nFlag = false
        hFlag = false
        cFlag = oldRegisterValue.checkBit(0)
    }
    
    private func checkBit(opcode: UInt8) {
        let relativeOpcode = opcode - 0x40
        let bitIndex = Int(relativeOpcode / 8)
        let registerValue = getRegisterByte(opcode: opcode)
        let isBitSet = registerValue.checkBit(bitIndex)
        zFlag = !isBitSet
        nFlag = false
        hFlag = true
    }
    
    private func resetBit(opcode: UInt8) {
        let relativeOpcode = opcode - 0x80
        let bitIndex = Int(relativeOpcode / 8)
        var registerValue = getRegisterByte(opcode: opcode)
        registerValue.clearBit(bitIndex)
        setRegisterValueForOpcode(opcode, value: registerValue)
    }
    
    private func setBit(opcode: UInt8) {
        let relativeOpcode = opcode - 0xC0
        let bitIndex = Int(relativeOpcode / 8)
        var registerValue = getRegisterByte(opcode: opcode)
        registerValue.setBit(bitIndex)
        setRegisterValueForOpcode(opcode, value: registerValue)
    }
}
