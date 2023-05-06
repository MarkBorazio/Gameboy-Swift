//
//  CPU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

// TODO: Consider using function builders

// Everything in here works in mCycles
// 1 mCycle == 4 tCycles
class CPU {
    
    // Individual Registers
    private var a: UInt8 = 0
    private var f: UInt8 = 0 {
        didSet { f &= 0xF0 } // Low nibble must always be all zeroes
    }
    private var b: UInt8 = 0
    private var c: UInt8 = 0
    private var d: UInt8 = 0
    private var e: UInt8 = 0
    private var h: UInt8 = 0
    private var l: UInt8 = 0
    
    // Register Pairs
    private var af: UInt16 {
        get { UInt16(bytes: [f, a])! }
        set {
            a = UInt8(newValue >> 8)
            f = UInt8(newValue & 0xFF)
        }
    }
    private var bc: UInt16 {
        get { UInt16(bytes: [c, b])! }
        set {
            b = UInt8(newValue >> 8)
            c = UInt8(newValue & 0xFF)
        }
    }
    private var de: UInt16 {
        get { UInt16(bytes: [e, d])! }
        set {
            d = UInt8(newValue >> 8)
            e = UInt8(newValue & 0xFF)
        }
    }
    private var hl: UInt16 {
        get { UInt16(bytes: [l, h])! }
        set {
            h = UInt8(newValue >> 8)
            l = UInt8(newValue & 0xFF)
        }
    }
    private var sp: UInt16 = 0
    private var pc: UInt16 = 0
    
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
    private var interruptMasterEnableFlag = false
    private var haltFlag = false
    private var stopFlag = false // TODO: Figure out when this should be reset.
    
    // When interrupts are enabled (EI instruction), the flag is set after the next instruction is executed.
    // Therefore, we need to use this "pending" flag instead of setting the `interruptMasterEnableFlag` instantly.
    // Ref: https://gbdev.io/pandocs/Interrupts.html
    private var pendingInterruptMasterEnable = true

    func tickReturningMCycles() -> Int {
        var totalCyclesThisTick = 0
        totalCyclesThisTick += executeInstruction()
        totalCyclesThisTick += handleInterrupts()
        
        if pendingInterruptMasterEnable {
            interruptMasterEnableFlag = true
            pendingInterruptMasterEnable = false
        }
        
        return totalCyclesThisTick
    }
    
    /// Execute the next instruction and returns the number of cycles it took.
    private func executeInstruction() -> Int {
        guard !haltFlag else { return 0 }
        
//        print("--- PC: \(pc.hexString())")
        let opcode = fetchNextByte()
        
        let value: Int
        if opcode == 0xCB {
//            print("Byte was 0xCB")
            value = execute16BitInstruction()
        } else {
            value = execute8BitInstruction(opcode: opcode)
        }
        
        return value
    }
    
    /// Checks for any interrupts and returns the number of cycles the check took.
    private func handleInterrupts() -> Int {
        if GameBoy.instance.mmu.hasPendingAndEnabledInterrupt {
            haltFlag = false
            if interruptMasterEnableFlag {
                guard let nextInterruptAddress = GameBoy.instance.mmu.getNextPendingAndEnabledInterrupt() else {
                    fatalError("This should never be `nil` at this point")
                }
                interruptMasterEnableFlag = false
                let cycles = pushOntoStack(address: pc)
                pc = nextInterruptAddress
                return cycles
            }
        }
        return 0
    }
    
    private func fetchNextByte() -> UInt8 {
        let byte = GameBoy.instance.mmu.safeReadValue(globalAddress: pc)
        pc &+= 1
        return byte
    }
    
    private func fetchNextShort() -> UInt16 {
        return UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
    }
    
    private func fetchByteAtNextAddress() -> UInt8 {
        return GameBoy.instance.mmu.safeReadValue(globalAddress: fetchNextShort())
    }
    
    func skipBootRom() {
        af = 0x01B0
        bc = 0x0013
        de = 0x00D8
        hl = 0x014D
        sp = 0xFFFE
        pc = 0x0100
    }
}

// MARK: - 8-bit Instructions

extension CPU {
    
    /// Execute the instruction from the opcode and returns the number of cycles it took.
    private func execute8BitInstruction(opcode: UInt8) -> Int {
//        print("Excuting 8-Bit Instruction: \(opcode.hexString())")
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
        case 0x18: return relativeJump()
        case 0x19: return addToHL(de)
        case 0x1A: return loadValueIntoRegister(register: &a, address: de)
        case 0x1B: return decrementPair(&de)
        case 0x1C: return incrementRegister(&e)
        case 0x1D: return decrementRegister(&e)
        case 0x1E: return loadImmediateByteIntoRegister(&e)
        case 0x1F: return rotateARightThroughCarry()
            
        case 0x20: return relativeJump(condition: !zFlag)
        case 0x21: return loadImmediateShortIntoPair(&hl)
        case 0x22: return loadRegisterIntoAddress(address: hl, register: a, hlOperation: .increment)
        case 0x23: return incrementPair(&hl)
        case 0x24: return incrementRegister(&h)
        case 0x25: return decrementRegister(&h)
        case 0x26: return loadImmediateByteIntoRegister(&h)
        case 0x27: return decimalAdjustAfterAddition()
        case 0x28: return relativeJump(condition: zFlag)
        case 0x29: return addToHL(hl)
        case 0x2A: return loadValueIntoRegister(register: &a, address: hl, hlOperation: .increment)
        case 0x2B: return decrementPair(&hl)
        case 0x2C: return incrementRegister(&l)
        case 0x2D: return decrementRegister(&l)
        case 0x2E: return loadImmediateByteIntoRegister(&l)
        case 0x2F: return flipBitsInA()
            
        case 0x30: return relativeJump(condition: !cFlag)
        case 0x31: return loadImmediateShortIntoPair(&sp)
        case 0x32: return loadRegisterIntoAddress(address: hl, register: a, hlOperation: .decrement)
        case 0x33: return incrementPair(&sp)
        case 0x34: return incrementValue(address: hl)
        case 0x35: return decrementValue(address: hl)
        case 0x36: return loadImmediateByteIntoAddress(hl)
        case 0x37: return setCFlag()
        case 0x38: return relativeJump(condition: cFlag)
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
            
        case 0x80: return addOperation(lhs: &a, rhs: b, carry: false)
        case 0x81: return addOperation(lhs: &a, rhs: c, carry: false)
        case 0x82: return addOperation(lhs: &a, rhs: d, carry: false)
        case 0x83: return addOperation(lhs: &a, rhs: e, carry: false)
        case 0x84: return addOperation(lhs: &a, rhs: h, carry: false)
        case 0x85: return addOperation(lhs: &a, rhs: l, carry: false)
        case 0x86: return addOperation(lhs: &a, address: hl, carry: false)
        case 0x87: return addOperation(lhs: &a, rhs: a, carry: false)
        case 0x88: return addOperation(lhs: &a, rhs: b, carry: cFlag)
        case 0x89: return addOperation(lhs: &a, rhs: c, carry: cFlag)
        case 0x8A: return addOperation(lhs: &a, rhs: d, carry: cFlag)
        case 0x8B: return addOperation(lhs: &a, rhs: e, carry: cFlag)
        case 0x8C: return addOperation(lhs: &a, rhs: h, carry: cFlag)
        case 0x8D: return addOperation(lhs: &a, rhs: l, carry: cFlag)
        case 0x8E: return addOperation(lhs: &a, address: hl, carry: cFlag)
        case 0x8F: return addOperation(lhs: &a, rhs: a, carry: cFlag)
            
        case 0x90: return subtractOperation(lhs: &a, rhs: b, carry: false)
        case 0x91: return subtractOperation(lhs: &a, rhs: c, carry: false)
        case 0x92: return subtractOperation(lhs: &a, rhs: d, carry: false)
        case 0x93: return subtractOperation(lhs: &a, rhs: e, carry: false)
        case 0x94: return subtractOperation(lhs: &a, rhs: h, carry: false)
        case 0x95: return subtractOperation(lhs: &a, rhs: l, carry: false)
        case 0x96: return subtractOperation(lhs: &a, address: hl, carry: false)
        case 0x97: return subtractOperation(lhs: &a, rhs: a, carry: false)
        case 0x98: return subtractOperation(lhs: &a, rhs: b, carry: cFlag)
        case 0x99: return subtractOperation(lhs: &a, rhs: c, carry: cFlag)
        case 0x9A: return subtractOperation(lhs: &a, rhs: d, carry: cFlag)
        case 0x9B: return subtractOperation(lhs: &a, rhs: e, carry: cFlag)
        case 0x9C: return subtractOperation(lhs: &a, rhs: h, carry: cFlag)
        case 0x9D: return subtractOperation(lhs: &a, rhs: l, carry: cFlag)
        case 0x9E: return subtractOperation(lhs: &a, address: hl, carry: cFlag)
        case 0x9F: return subtractOperation(lhs: &a, rhs: a, carry: cFlag)
            
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
        case 0xC6: return addNextByteToA(carry: false)
        case 0xC7: return restart(offset: 0)
        case 0xC8: return returnControl(condition: zFlag)
        case 0xC9: return returnControl()
        case 0xCA: return jumpToNextByteAddress(condition: zFlag)
        case 0xCB: break
        case 0xCC: return call(condition: zFlag)
        case 0xCD: return call()
        case 0xCE: return addNextByteToA(carry: cFlag)
        case 0xCF: return restart(offset: 1)
            
        case 0xD0: return returnControl(condition: !cFlag)
        case 0xD1: return popStack(into: &de)
        case 0xD2: return jumpToNextByteAddress(condition: !cFlag)
        case 0xD3: break
        case 0xD4: return call(condition: !cFlag)
        case 0xD5: return pushOntoStack(address: de)
        case 0xD6: return subtractNextByteFromA(carry: false)
        case 0xD7: return restart(offset: 2)
        case 0xD8: return returnControl(condition: cFlag)
        case 0xD9: return returnControlEnablingInterrupt()
        case 0xDA: return jumpToNextByteAddress(condition: cFlag)
        case 0xDB: break
        case 0xDC: return call(condition: cFlag)
        case 0xDD: break
        case 0xDE: return subtractNextByteFromA(carry: cFlag)
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
        GameBoy.instance.mmu.safeWriteValue(sp.getByte(0), globalAddress: address)
        GameBoy.instance.mmu.safeWriteValue(sp.getByte(1), globalAddress: address+1)
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

    /// 0x27
    private func decimalAdjustAfterAddition() -> Int {
        // Refs:
        // https://ehaskins.com/2018-01-30%20Z80%20DAA/
        // https://binji.github.io/posts/pokegb/
        
        var bcdCorrection: UInt8 = 0
        var shouldSetCarry = false
        if (hFlag || (!nFlag && a.lowNibble > 0x9)) {
            bcdCorrection &+= 0x6
        }
        if (cFlag || (!nFlag && a > 0x99)) {
            bcdCorrection &+= 0x60
            shouldSetCarry = true
        }
        
        if nFlag {
            a &-= bcdCorrection
        } else {
            a &+= bcdCorrection
        }
        
        zFlag = a == 0
        hFlag = false
        if shouldSetCarry { // TODO: Determine if we should ever set to false or not
            cFlag = true
        }
        
        return 1
    }
    
    /// 0x2F
    private func flipBitsInA() -> Int {
        a = ~a
        nFlag = true
        hFlag = true
        
        return 1
    }
    
    /// 0x37
    private func setCFlag() -> Int {
        cFlag = true
        // Also need to clear n and h flags
        nFlag = false
        hFlag = false
        
        return 1
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
        GameBoy.instance.mmu.safeWriteValue(register, globalAddress: address)
        executeHLOperation(hlOperation)
        return 2
    }
    
    // 0x36
    private func loadImmediateByteIntoAddress(_ address: UInt16) -> Int {
        let value = fetchNextByte()
        GameBoy.instance.mmu.safeWriteValue(value, globalAddress: address)
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
        register = GameBoy.instance.mmu.safeReadValue(globalAddress: address)
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
        GameBoy.instance.mmu.safeWriteValue(a, globalAddress: address)
        return 3
    }
    
    // 0xF0
    private func highPageLoadNextByteAddressIntoA() -> Int {
        let lowerByte = fetchNextByte()
        let address = UInt16(bytes: [lowerByte, 0xFF])!
        a = GameBoy.instance.mmu.safeReadValue(globalAddress: address)
        return 3
    }
    
    // 0xE2
    private func highPageLoadAIntoAddressC() -> Int {
        let address = UInt16(bytes: [c, 0xFF])!
        GameBoy.instance.mmu.safeWriteValue(a, globalAddress: address)
        return 2
    }
    
    // 0xF2
    private func highPageLoadAddressCIntoA() -> Int {
        let address = UInt16(bytes: [c, 0xFF])!
        a = GameBoy.instance.mmu.safeReadValue(globalAddress: address)
        return 2
    }
    
    // 0xEA
    private func loadAIntoShortAddress() -> Int {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        GameBoy.instance.mmu.safeWriteValue(a, globalAddress: address)
        return 4
    }
    
    // 0xEA, 0xFA
    private func loadShortAddressIntoA() -> Int {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        a = GameBoy.instance.mmu.safeReadValue(globalAddress: address)
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
        let value = GameBoy.instance.mmu.safeReadValue(globalAddress: address)
        let incrementedValue = incrementOperation(value)
        GameBoy.instance.mmu.safeWriteValue(incrementedValue, globalAddress: address)
        return 3
    }
    
    /// 0x35
    private func decrementValue(address: UInt16) -> Int {
        let value = GameBoy.instance.mmu.safeReadValue(globalAddress: address)
        let decrementedValue = decrementOperation(value)
        GameBoy.instance.mmu.safeWriteValue(decrementedValue, globalAddress: address)
        return 3
    }
    
    // MARK: - Arithmetical Operations

    // 0xE8
    private func addNextByteToSP() -> Int {
        let signedByte = Int8(bitPattern: fetchNextByte())
        sp = addOperation(lhs: sp, rhs: signedByte)
        return 4
    }
    
    // 0xC6, 0xCE
    private func addNextByteToA(carry: Bool) -> Int {
        let byte = fetchNextByte()
        _ = addOperation(lhs: &a, rhs: byte, carry: carry)
        return 2
    }
        
    // 0x09, 0x19, 0x29, 0x39
    private func addToHL(_ value: UInt16) -> Int {
        // Ref: https://stackoverflow.com/a/57981912
        
        // Do separate 8-bit additions on both bytes to ensure that the approriate flags are set.
        // Then, discard these results and do a standard 16-bit addition on `hl` ensure that we overflow correctly.
        let oldZflag = zFlag
        var discardableH = h
        var discardableL = l
        _ = addOperation(lhs: &discardableL, rhs: value.getByte(0), carry: false)
        _ = addOperation(lhs: &discardableH, rhs: value.getByte(1), carry: cFlag)
        
        // Update remaining values
        zFlag = oldZflag // ZFlag state remains unchanged
        hl &+= value
        
        return 2
    }
    
    // 0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x87, 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8F
    private func addOperation(lhs: inout UInt8, rhs: UInt8, carry: Bool) -> Int {
        let carryValue: UInt8 = carry ? 1 : 0
        let (value, newCarry) = lhs.addingMultipleReportingOverflow(rhs, carryValue)
        let halfCarry = calculateHalfCarryFromAddition(lhs: lhs, rhs: rhs, carry: carry)
        
        lhs = value
        
        zFlag = value == 0
        nFlag = false
        hFlag = halfCarry
        cFlag = newCarry
        
        return 1
    }
    
    // 0x86, 0x8E
    private func addOperation(lhs: inout UInt8, address: UInt16, carry: Bool) -> Int {
        let rhs = GameBoy.instance.mmu.safeReadValue(globalAddress: address)
        _ = addOperation(lhs: &lhs, rhs: rhs, carry: carry)
        return 2
    }
    
    // 0xD6, 0xDE
    private func subtractNextByteFromA(carry: Bool) -> Int {
        let byte = fetchNextByte()
        _ = subtractOperation(lhs: &a, rhs: byte, carry: carry)
        return 2
    }
    
    // 0x90, 0x91, 0x92, 0x93, 0x94, 0x95, 0x97, 0x98, 0x99, 0x9A, 0x9B, 0x9C, 0x9D, 0x9F
    private func subtractOperation(lhs: inout UInt8, rhs: UInt8, carry: Bool) -> Int {
        let carryValue: UInt8 = carry ? 1 : 0
        let (value, newCarry) = lhs.subtractingMultipleReportingOverflow(rhs, carryValue)
        let halfCarry = calculateHalfCarryFromSubtraction(lhs: lhs, rhs: rhs, carry: carry)
        
        lhs = value
        
        zFlag = value == 0
        nFlag = true
        hFlag = halfCarry
        cFlag = newCarry
        
        return 1
    }
    
    // 0x96, 0x9E
    private func subtractOperation(lhs: inout UInt8, address: UInt16, carry: Bool) -> Int {
        let rhs = GameBoy.instance.mmu.safeReadValue(globalAddress: address)
        _ = subtractOperation(lhs: &lhs, rhs: rhs, carry: carry)
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
        let rhs = GameBoy.instance.mmu.safeReadValue(globalAddress: address)
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
        let rhs = GameBoy.instance.mmu.safeReadValue(globalAddress: address)
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
        let rhs = GameBoy.instance.mmu.safeReadValue(globalAddress: address)
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
        let halfCarry = calculateHalfCarryFromSubtraction(lhs: lhs, rhs: rhs, carry: false)
        
        zFlag = comparison == 0
        nFlag = true
        hFlag = halfCarry
        cFlag = carry
        
        return 1
    }
    
    // 0xBE
    private func compare(lhs: UInt8, address: UInt16) -> Int {
        let rhs = GameBoy.instance.mmu.safeReadValue(globalAddress: address)
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
        interruptMasterEnableFlag = true
        return 4
    }
    
    // 0xC1, 0xD1, 0xE1, 0xF1
    private func popStack(into pair: inout UInt16) -> Int {
        pair = popStack()
        return 3
    }
    
    // 0xC5, 0xD5, 0xE5, 0xF5
    private func pushOntoStack(address: UInt16) -> Int {
        let lowerByte = address.getByte(0)
        let upperByte = address.getByte(1)
        
        sp &-= 1
        GameBoy.instance.mmu.safeWriteValue(upperByte, globalAddress: sp)
        sp &-= 1
        GameBoy.instance.mmu.safeWriteValue(lowerByte, globalAddress: sp)
        
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
     // 0x18, 0x20, 0x28, 0x30
    private func relativeJump(condition: Bool = true) -> Int {
        let operand = fetchNextByte()
        if condition {
            let offset = Int8(bitPattern: operand)
            let offsetMagnitude = UInt16(offset.magnitude)
            
            let isPositive = offset >= 0
            if isPositive {
                pc &+= offsetMagnitude
            } else {
                pc &-= offsetMagnitude
            }
            return 3
        } else {
            return 2
        }
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
        pendingInterruptMasterEnable = false
        interruptMasterEnableFlag = false
        return 1
    }
    
    // 0xFB
    private func scheduleInterruptHandling() -> Int {
        pendingInterruptMasterEnable = true
        return 1
    }
}

// MARK: - 16-bit Instructions (Opcodes with 0xCB prefix)

extension CPU {
    
    private func execute16BitInstruction() -> Int {
        let opcode = fetchNextByte()
//        print("Executing 8-Bit Instruction: \(opcode.hexString())")
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
        case 0x6, 0xE: return GameBoy.instance.mmu.safeReadValue(globalAddress: hl)
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
        case 0x6, 0xE: GameBoy.instance.mmu.safeWriteValue(value, globalAddress: hl)
        case 0x7, 0xF: a = value
        default: fatalError("Failed to set byte register for opcode: \(opcode)")
        }
    }
}

// MARK: - Arithmetic, Boolean Logic, and Control

extension CPU {
    
    private func popStack() -> UInt16 {
        let lowerByte = GameBoy.instance.mmu.safeReadValue(globalAddress: sp)
        sp &+= 1
        let upperByte = GameBoy.instance.mmu.safeReadValue(globalAddress: sp)
        sp &+= 1
        return UInt16(bytes: [lowerByte, upperByte])!
    }

    
    private func incrementOperation(_ value: UInt8) -> UInt8 {
        let incrementedValue = value &+ 1
        let halfCarry = calculateHalfCarryFromAddition(lhs: value, rhs: 1, carry: false)
        
        zFlag = incrementedValue == 0
        nFlag = false
        hFlag = halfCarry
        
        return incrementedValue
    }
    
    private func decrementOperation(_ value: UInt8) -> UInt8 {
        let decrementedValue = value &- 1
        let halfCarry = calculateHalfCarryFromSubtraction(lhs: value, rhs: 1, carry: false)

        zFlag = decrementedValue == 0
        nFlag = true
        hFlag = halfCarry
        
        return decrementedValue
    }
    
    // Ref: https://stackoverflow.com/a/57978555
    private func addOperation(lhs: UInt16, rhs: Int8) -> UInt16 {
        // Carry and Half-Carry flags are calculated on lower byte as if it were an 8-bit operation.
        let unsignedRhs = UInt8(bitPattern: rhs)
        let (_, carry) = lhs.getByte(0).addingReportingOverflow(unsignedRhs)
        let halfCarry = calculateHalfCarryFromAddition(lhs: lhs.getByte(0), rhs: unsignedRhs, carry: false)
        
        // Flag are calculated by this point, so we calculate result normally
        let value = lhs &+ UInt16(bitPattern: Int16(rhs))
        
        zFlag = false
        nFlag = false
        hFlag = halfCarry
        cFlag = carry
        
        return value
    }
    
    private func calculateHalfCarryFromAddition(lhs: UInt8, rhs: UInt8, carry: Bool) -> Bool {
        let carryValue: UInt8 = carry ? 1 : 0
        let result = (lhs.lowNibble &+ rhs.lowNibble &+ carryValue) & 0x10
        return result == 0x10
    }
     
    // Ref: https://www.reddit.com/r/EmuDev/comments/knm196/gameboy_half_carry_flag_during_subtract_operation/
    private func calculateHalfCarryFromSubtraction(lhs: UInt8, rhs: UInt8, carry: Bool) -> Bool {
        let carryValue: UInt8 = carry ? 1 : 0
        let result = (lhs.lowNibble &- rhs.lowNibble &- carryValue) & 0x10
        return result == 0x10
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
