//
//  CPU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

class CPU {
    
    let mmu = MMU()
    
    // Register Pairs
    private var af: UInt16 = 0
    private var bc: UInt16 = 0
    private var de: UInt16 = 0
    private var hl: UInt16 = 0
    private var sp: UInt16 = 0
    private var pc: UInt16 = 0
    
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
    
    // Clock
    private static let clockCycleHz: UInt32 = 4194304
    private static let clockCyclesPerMachineCycle: UInt32 = 4
    private static let machineCycleHz: UInt32 = clockCycleHz / clockCyclesPerMachineCycle
    
    private static let machineCyclesPerDivCycle = 256 / clockCyclesPerMachineCycle
    private var divTimer = 0
    private var timaTimer = 0 // Increments at configurable frequency
    
    func beginExecution() {
        while(true) {
            executeInstruction()
            
            // Handle interrupt if necessary
            if imeFlag {
                if let interruptAddress = mmu.checkForInterrupt() {
                    imeFlag = false
                    pushOntoStack(address: pc)
                    pc = interruptAddress
                }
            }
            
            incrementTimers()
            
            sleep(Self.machineCycleHz)
        }
    }
    
    private func executeInstruction() {
        let opcode = fetchNextByte()
        if opcode == 0xCB {
            execute16BitInstruction()
        } else {
            execute8BitInstruction(opcode: opcode)
        }
    }
    
    private func incrementTimers() {
        divTimer += 1
        if divTimer >= Self.machineCyclesPerDivCycle {
            divTimer = 0
            mmu.incrementDivRegister()
        }
        
        timaTimer += 1
        let machineCyclesPerTimaCycle = mmu.clockCyclesPerTimaCycle / Self.clockCyclesPerMachineCycle
        if timaTimer >= machineCyclesPerTimaCycle {
            timaTimer = 0
            mmu.incrementTimaRegister()
        }
    }
}

// MARK: - 8-bit Instructions

extension CPU {
    
    private func execute8BitInstruction(opcode: UInt8) {
    
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
            
        case 0x10: stop()
        case 0x11: loadShortIntoDE()
        case 0x12: loadAIntoAbsoluteDE()
        case 0x13: incrementDE()
        case 0x14: incrementD()
        case 0x15: decrementD()
        case 0x16: loadByteIntoD()
        case 0x17: rotateALeftThroughCarry()
        case 0x18: unconditionalRelativeJump()
        case 0x19: addDEtoHL()
        case 0x1A: loadAbsoluteDEIntoA()
        case 0x1B: decrementDE()
        case 0x1C: incrementE()
        case 0x1D: decrementE()
        case 0x1E: loadByteIntoE()
        case 0x1F: rotateARightThroughCarry()
            
        case 0x20: relativeJumpIfZFlagCleared()
        case 0x21: loadShortIntoHL()
        case 0x22: loadAIntoAbsoluteHLAndIncrementHL()
        case 0x23: incrementHL()
        case 0x24: incrementH()
        case 0x25: decrementH()
        case 0x26: loadByteIntoH()
        case 0x27: decimalAdjustAfterAddition()
        case 0x28: relativeJumpIfZFlagSet()
        case 0x29: addHLtoHL()
        case 0x2A: loadAbsoluteHLIntoAAndIncrementHL()
        case 0x2B: decrementHL()
        case 0x2C: incrementL()
        case 0x2D: decrementL()
        case 0x2E: loadByteIntoL()
        case 0x2F: flipBitsInA()
            
        case 0x30: relativeJumpIfCFlagCleared()
        case 0x31: loadShortIntoSP()
        case 0x32: loadAIntoAbsoluteHLAndDecrementHL()
        case 0x33: incrementSP()
        case 0x34: incrementAbsoluteHL()
        case 0x35: decrementAbsoluteHL()
        case 0x36: loadByteIntoAbsoluteHL()
        case 0x37: setCFlag()
        case 0x38: relativeJumpIfCFlagSet()
        case 0x39: addSPtoHL()
        case 0x3A: loadAbsoluteHLIntoAAndDecrementHL()
        case 0x3B: decrementSP()
        case 0x3C: incrementA()
        case 0x3D: decrementA()
        case 0x3E: loadByteIntoA()
        case 0x3F: flipCFlag()
            
        case 0x40: loadBIntoB()
        case 0x41: loadCIntoB()
        case 0x42: loadDIntoB()
        case 0x43: loadEIntoB()
        case 0x44: loadHIntoB()
        case 0x45: loadLIntoB()
        case 0x46: loadAbsoluteHLIntoB()
        case 0x47: loadAIntoB()
        case 0x48: loadBIntoC()
        case 0x49: loadCIntoC()
        case 0x4A: loadDIntoC()
        case 0x4B: loadEIntoC()
        case 0x4C: loadHIntoC()
        case 0x4D: loadLIntoC()
        case 0x4E: loadAbsoluteHLIntoC()
        case 0x4F: loadAIntoC()
            
        case 0x50: loadBIntoD()
        case 0x51: loadCIntoD()
        case 0x52: loadDIntoD()
        case 0x53: loadEIntoD()
        case 0x54: loadHIntoD()
        case 0x55: loadLIntoD()
        case 0x56: loadAbsoluteHLIntoD()
        case 0x57: loadAIntoD()
        case 0x58: loadBIntoE()
        case 0x59: loadCIntoE()
        case 0x5A: loadDIntoE()
        case 0x5B: loadEIntoE()
        case 0x5C: loadHIntoE()
        case 0x5D: loadLIntoE()
        case 0x5E: loadAbsoluteHLIntoE()
        case 0x5F: loadAIntoE()
            
        case 0x60: loadBIntoH()
        case 0x61: loadCIntoH()
        case 0x62: loadDIntoH()
        case 0x63: loadEIntoH()
        case 0x64: loadHIntoH()
        case 0x65: loadLIntoH()
        case 0x66: loadAbsoluteHLIntoH()
        case 0x67: loadAIntoH()
        case 0x68: loadBIntoL()
        case 0x69: loadCIntoL()
        case 0x6A: loadDIntoL()
        case 0x6B: loadEIntoL()
        case 0x6C: loadHIntoL()
        case 0x6D: loadLIntoL()
        case 0x6E: loadAbsoluteHLIntoL()
        case 0x6F: loadAIntoL()
            
        case 0x70: loadBIntoAbsoluteHL()
        case 0x71: loadCIntoAbsoluteHL()
        case 0x72: loadDIntoAbsoluteHL()
        case 0x73: loadEIntoAbsoluteHL()
        case 0x74: loadHIntoAbsoluteHL()
        case 0x75: loadLIntoAbsoluteHL()
        case 0x76: halt()
        case 0x77: loadAIntoAbsoluteHL()
        case 0x78: loadBIntoA()
        case 0x79: loadCIntoA()
        case 0x7A: loadDIntoA()
        case 0x7B: loadEIntoA()
        case 0x7C: loadHIntoA()
        case 0x7D: loadLIntoA()
        case 0x7E: loadAbsoluteHLIntoA()
        case 0x7F: loadAIntoA()
            
        case 0x80: addBToA()
        case 0x81: addCToA()
        case 0x82: addDToA()
        case 0x83: addEToA()
        case 0x84: addHToA()
        case 0x85: addLToA()
        case 0x86: addAbsoluteHLToA()
        case 0x87: addAToA()
        case 0x88: addBWithCarryToA()
        case 0x89: addCWithCarryToA()
        case 0x8A: addDWithCarryToA()
        case 0x8B: addEWithCarryToA()
        case 0x8C: addHWithCarryToA()
        case 0x8D: addLWithCarryToA()
        case 0x8E: addAbsoluteHLWithCarryToA()
        case 0x8F: addAWithCarryToA()
            
        case 0x90: subtractBFromA()
        case 0x91: subtractCFromA()
        case 0x92: subtractDFromA()
        case 0x93: subtractEFromA()
        case 0x94: subtractHFromA()
        case 0x95: subtractLFromA()
        case 0x96: subtractAbsoluteHLFromA()
        case 0x97: subtractAFromA()
        case 0x98: subtractBWithCarryFromA()
        case 0x99: subtractCWithCarryFromA()
        case 0x9A: subtractDWithCarryFromA()
        case 0x9B: subtractEWithCarryFromA()
        case 0x9C: subtractHWithCarryFromA()
        case 0x9D: subtractLWithCarryFromA()
        case 0x9E: subtractAbsoluteHLWithCarryFromA()
        case 0x9F: subtractAWithCarryFromA()
            
        case 0xA0: logicalAndBToA()
        case 0xA1: logicalAndCToA()
        case 0xA2: logicalAndDToA()
        case 0xA3: logicalAndEToA()
        case 0xA4: logicalAndHToA()
        case 0xA5: logicalAndLToA()
        case 0xA6: logicalAndAbsoluteHLToA()
        case 0xA7: logicalAndAToA()
        case 0xA8: logicalXorBToA()
        case 0xA9: logicalXorCToA()
        case 0xAA: logicalXorDToA()
        case 0xAB: logicalXorEToA()
        case 0xAC: logicalXorHToA()
        case 0xAD: logicalXorLToA()
        case 0xAE: logicalXorAbsoluteHLToA()
        case 0xAF: logicalXorAToA()
            
        case 0xB0: logicalOrBToA()
        case 0xB1: logicalOrCToA()
        case 0xB2: logicalOrDToA()
        case 0xB3: logicalOrEToA()
        case 0xB4: logicalOrHToA()
        case 0xB5: logicalOrLToA()
        case 0xB6: logicalOrAbsoluteHLToA()
        case 0xB7: logicalOrAToA()
        case 0xB8: compareBToA()
        case 0xB9: compareCToA()
        case 0xBA: compareDToA()
        case 0xBB: compareEToA()
        case 0xBC: compareHToA()
        case 0xBD: compareLToA()
        case 0xBE: compareAbsoluteHLToA()
        case 0xBF: compareAToA()
            
        case 0xC0: returnIfZFlagCleared()
        case 0xC1: popStackIntoBC()
        case 0xC2: absoluteJumpIfZFlagCleared()
        case 0xC3: unconditionalAbsoluteJump()
        case 0xC4: callIfZFlagCleared()
        case 0xC5: pushBCOntoStack()
        case 0xC6: addByteToA()
        case 0xC7: resetToByte0()
        case 0xC8: returnIfZFlagSet()
        case 0xC9: unconditionalReturn()
        case 0xCA: absoluteJumpIfZFlagSet()
        case 0xCB: break
        case 0xCC: callIfZFlagSet()
        case 0xCD: unconditionalCall()
        case 0xCE: addByteWithCarryToA()
        case 0xCF: resetToByte1()
            
        case 0xD0: returnIfCFlagCleared()
        case 0xD1: popStackIntoDE()
        case 0xD2: absoluteJumpIfCFlagCleared()
        case 0xD3: break
        case 0xD4: callIfCFlagCleared()
        case 0xD5: pushDEOntoStack()
        case 0xD6: subtractByteFromA()
        case 0xD7: resetToByte2()
        case 0xD8: returnIfCFlagSet()
        case 0xD9: unconditionalReturnWithInterrupt()
        case 0xDA: absoluteJumpIfCFlagSet()
        case 0xDB: break
        case 0xDC: callIfCFlagSet()
        case 0xDD: break
        case 0xDE: subtractByteWithCarryToA()
        case 0xDF: resetToByte3()
            
        case 0xE0: highPageLoadAIntoByteAddress()
        case 0xE1: popStackIntoHL()
        case 0xE2: highPageLoadAIntoAbsoluteC()
        case 0xE3: break
        case 0xE4: break
        case 0xE5: pushHLOntoStack()
        case 0xE6: logicalAndByteToA()
        case 0xE7: resetToByte4()
        case 0xE8: addByteToSP()
        case 0xE9: jumpToHL()
        case 0xEA: loadAIntoShortAddress()
        case 0xEB: break
        case 0xEC: break
        case 0xED: break
        case 0xEE: logicalXorByteToA()
        case 0xEF: resetToByte5()
            
        case 0xF0: highPageLoadAbsoluteByteAddressIntoA()
        case 0xF1: popStackIntoAF()
        case 0xF2: highPageLoadAbsoluteCIntoA()
        case 0xF3: disableInterruptHandling()
        case 0xF4: break
        case 0xF5: pushAFOntoStack()
        case 0xF6: logicalOrByteToA()
        case 0xF7: resetToByte6()
        case 0xF8: loadSPPlusByteIntoHL()
        case 0xF9: loadHLIntoSP()
        case 0xFA: loadAbsoluteShortAddressIntoA()
        case 0xFB: scheduleInterruptHandling()
        case 0xFC: break
        case 0xFD: break
        case 0xFE: compareByteToA()
        case 0xFF: resetToByte7()
            
        default: fatalError("Encountered unknown 8-bit opcode.")
        }
    }
    
    /// 0x00
    private func noOp() {
        // No Operation
    }
    
    /// 0x01
    private func loadShortIntoBC() {
        let value = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        bc = value
    }
    
    /// 0x02
    private func loadAIntoAbsoluteBC() {
        mmu.writeValue(a, address: bc)
    }
    
    /// 0x03
    private func incrementBC() {
        bc &+= 1
    }
    
    /// 0x04
    private func incrementB() {
        b = incrementOperation(b)
    }
    
    /// 0x05
    private func decrementB() {
        b = decrementOperation(b)
    }
    
    /// 0x06
    private func loadByteIntoB() {
        b = fetchNextByte()
    }
    
    /// 0x07
    private func rotateALeftWithCarry() {
        cFlag = a.checkBit(7)
        a = a.bitwiseLeftRotation(amount: 1)
        zFlag = false
        nFlag = false
        hFlag = false
    }
    
    /// 0x08
    private func loadSPIntoAddress() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        mmu.writeValue(sp.asBytes()[0], address: address)
        mmu.writeValue(sp.asBytes()[1], address: address+1)
    }
    
    /// 0x09
    private func addBCtoHL() {
        hl = addOperation(lhs: hl, rhs: bc)
    }
    
    /// 0x0A
    private func loadAbsoluteBCIntoA() {
        a = mmu.readValue(address: bc)
    }
    
    /// 0x0B
    private func decrementBC() {
        bc &-= 1
    }
    
    /// 0x0C
    private func incrementC() {
        c = incrementOperation(c)
    }
    
    /// 0x0D
    private func decrementC() {
        c = decrementOperation(c)
    }
    
    /// 0x0E
    private func loadByteIntoC() {
        c = fetchNextByte()
    }
    
    /// 0x0F
    private func rotateARightWithCarry() {
        cFlag = a.checkBit(0)
        a = a.bitwiseRightRotation(amount: 1)
        zFlag = false
        nFlag = false
        hFlag = false
    }
    
    /// 0x10
    private func stop() {
        // Stop instruction is two bytes long, so we need to read the next byte as well.
        // 0x10, 0x00
        stop = true
        guard fetchNextByte() == 0x00 else { fatalError("Second byte of STOP instruction was not 0x00.") }
    }
    
    /// 0x11
    private func loadShortIntoDE() {
        let value = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        de = value
    }
    
    /// 0x12
    private func loadAIntoAbsoluteDE() {
        mmu.writeValue(a, address: de)
    }
    
    /// 0x13
    private func incrementDE() {
        de &+= 1
    }
    
    /// 0x14
    private func incrementD() {
        d = incrementOperation(d)
    }
    
    /// 0x15
    private func decrementD() {
        d = decrementOperation(d)
    }
    
    /// 0x16
    private func loadByteIntoD() {
        d = fetchNextByte()
    }
    
    /// 0x17
    private func rotateALeftThroughCarry() {
        let previousCarry = cFlag
        cFlag = a.checkBit(7)
        a = a.bitwiseLeftRotation(amount: 1)
        previousCarry ? a.setBit(0) : a.clearBit(0)
        zFlag = false
        nFlag = false
        hFlag = false
    }
    
    /// 0x18
    private func unconditionalRelativeJump() {
        relativeJump(byte: fetchNextByte())
    }
    
    /// 0x19
    private func addDEtoHL() {
        hl = addOperation(lhs: hl, rhs: de)
    }
    
    /// 0x1A
    private func loadAbsoluteDEIntoA() {
        a = mmu.readValue(address: de)
    }
    
    /// 0x1B
    private func decrementDE() {
        de &-= 1
    }
    
    /// 0x1C
    private func incrementE() {
        e = incrementOperation(e)
    }
    
    /// 0x1D
    private func decrementE() {
        e = decrementOperation(e)
    }
    
    /// 0x1E
    private func loadByteIntoE() {
        e = fetchNextByte()
    }
    
    /// 0x1F
    private func rotateARightThroughCarry() {
        let previousCarry = cFlag
        cFlag = a.checkBit(0)
        a = a.bitwiseRightRotation(amount: 1)
        previousCarry ? a.setBit(7) : a.clearBit(7)
        zFlag = false
        nFlag = false
        hFlag = false
    }
    
    /// 0x20
    private func relativeJumpIfZFlagCleared() {
        let operand = fetchNextByte()
        if !zFlag {
            relativeJump(byte: operand)
        }
    }
    
    /// 0x21
    private func loadShortIntoHL() {
        let value = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        hl = value
    }
    
    /// 0x22
    private func loadAIntoAbsoluteHLAndIncrementHL() {
        mmu.writeValue(a, address: hl)
        hl += 1
    }
    
    /// 0x23
    private func incrementHL() {
        hl &+= 1
    }
    
    /// 0x24
    private func incrementH() {
        h = incrementOperation(h)
    }
    
    /// 0x25
    private func decrementH() {
        h = decrementOperation(h)
    }
    
    /// 0x26
    private func loadByteIntoH() {
        h = fetchNextByte()
    }

    /// 0x27
    private func decimalAdjustAfterAddition() {
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
    }
    
    /// 0x28
    private func relativeJumpIfZFlagSet() {
        let operand = fetchNextByte()
        if zFlag {
            relativeJump(byte: operand)
        }
    }
    
    /// 0x29
    private func addHLtoHL() {
        hl = addOperation(lhs: hl, rhs: hl)
    }
    
    /// 0x2A
    private func loadAbsoluteHLIntoAAndIncrementHL() {
        a = mmu.readValue(address: hl)
        hl += 1
    }
    
    /// 0x2B
    private func decrementHL() {
        hl &-= 1
    }
    
    /// 0x2C
    private func incrementL() {
        l = incrementOperation(l)
    }
    
    /// 0x2D
    private func decrementL() {
        l = decrementOperation(l)
    }
    
    /// 0x2E
    private func loadByteIntoL() {
        l = fetchNextByte()
    }
    
    /// 0x2F
    private func flipBitsInA() {
        a = ~a
        nFlag = true
        hFlag = true
    }
    
    /// 0x30
    private func relativeJumpIfCFlagCleared() {
        let operand = fetchNextByte()
        if !cFlag {
            relativeJump(byte: operand)
        }
    }
    
    /// 0x31
    private func loadShortIntoSP() {
        let value = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        sp = value
    }
    
    /// 0x32
    private func loadAIntoAbsoluteHLAndDecrementHL() {
        mmu.writeValue(a, address: hl)
        hl -= 1
    }
    
    /// 0x33
    private func incrementSP() {
        sp &+= 1
    }
    
    /// 0x34
    private func incrementAbsoluteHL() {
        let value = mmu.readValue(address: hl)
        let incrementedValue = incrementOperation(value)
        mmu.writeValue(incrementedValue, address: hl)
    }
    
    /// 0x35
    private func decrementAbsoluteHL() {
        let value = mmu.readValue(address: hl)
        let decrementedValue = decrementOperation(value)
        mmu.writeValue(decrementedValue, address: hl)
    }
    
    /// 0x36
    private func loadByteIntoAbsoluteHL() {
        let byte = fetchNextByte()
        mmu.writeValue(byte, address: hl)
    }
    
    /// 0x37
    private func setCFlag() {
        cFlag = true
        // Also need to clear n and h flags
        nFlag = false
        hFlag = false
    }
    
    /// 0x38
    private func relativeJumpIfCFlagSet() {
        let operand = fetchNextByte()
        if cFlag {
            relativeJump(byte: operand)
        }
    }
    
    /// 0x39
    private func addSPtoHL() {
        hl = addOperation(lhs: hl, rhs: sp)
    }
    
    /// 0x3A
    private func loadAbsoluteHLIntoAAndDecrementHL() {
        a = mmu.readValue(address: hl)
        hl -= 1
    }
    
    /// 0x3B
    private func decrementSP() {
        sp &-= 1
    }
    
    /// 0x3C
    private func incrementA() {
        a = incrementOperation(a)
    }
    
    /// 0x3D
    private func decrementA() {
        a = decrementOperation(a)
    }
    
    /// 0x3E
    private func loadByteIntoA() {
        a = fetchNextByte()
    }
    
    /// 0x3F
    private func flipCFlag() {
        cFlag.toggle()
        // Also need to clear n and h flags
        nFlag = false
        hFlag = false
    }
    
    /// 0x40
    private func loadBIntoB() {
//        b = b
    }
    
    /// 0x41
    private func loadCIntoB() {
        b = c
    }
    
    /// 0x42
    private func loadDIntoB() {
        b = d
    }
    
    /// 0x43
    private func loadEIntoB() {
        b = e
    }
    
    /// 0x44
    private func loadHIntoB() {
        b = h
    }
    
    /// 0x45
    private func loadLIntoB() {
        b = l
    }
    
    /// 0x46
    private func loadAbsoluteHLIntoB() {
        b = mmu.readValue(address: hl)
    }
    
    /// 0x47
    private func loadAIntoB() {
        b = a
    }
    
    /// 0x48
    private func loadBIntoC() {
        c = b
    }
    
    /// 0x49
    private func loadCIntoC() {
//        c = c
    }
    
    /// 0x4A
    private func loadDIntoC() {
        c = d
    }
    
    /// 0x4B
    private func loadEIntoC() {
        c = e
    }
    
    /// 0x4C
    private func loadHIntoC() {
        c = h
    }
    
    /// 0x4D
    private func loadLIntoC() {
        c = l
    }
    
    /// 0x4E
    private func loadAbsoluteHLIntoC() {
        c = mmu.readValue(address: hl)
    }
    
    /// 0x4F
    private func loadAIntoC() {
        c = a
    }
    
    /// 0x50
    private func loadBIntoD() {
        d = b
    }
    
    /// 0x51
    private func loadCIntoD() {
        d = c
    }
    
    /// 0x52
    private func loadDIntoD() {
//        d = d
    }
    
    /// 0x53
    private func loadEIntoD() {
        d = e
    }
    
    /// 0x54
    private func loadHIntoD() {
        d = h
    }
    
    /// 0x55
    private func loadLIntoD() {
        d = l
    }
    
    /// 0x56
    private func loadAbsoluteHLIntoD() {
        d = mmu.readValue(address: hl)
    }
    
    /// 0x57
    private func loadAIntoD() {
        d = a
    }
    
    /// 0x58
    private func loadBIntoE() {
        e = b
    }
    
    /// 0x59
    private func loadCIntoE() {
        e = c
    }
    
    /// 0x5A
    private func loadDIntoE() {
        e = d
    }
    
    /// 0x5B
    private func loadEIntoE() {
//        e = e
    }
    
    /// 0x5C
    private func loadHIntoE() {
        e = h
    }
    
    /// 0x5D
    private func loadLIntoE() {
        e = l
    }
    
    /// 0x5E
    private func loadAbsoluteHLIntoE() {
        e = mmu.readValue(address: hl)
    }
    
    /// 0x5F
    private func loadAIntoE() {
        e = a
    }
    
    /// 0x60
    private func loadBIntoH() {
        h = b
    }
    
    /// 0x61
    private func loadCIntoH() {
        h = c
    }
    
    /// 0x62
    private func loadDIntoH() {
        h = d
    }
    
    /// 0x63
    private func loadEIntoH() {
        h = e
    }
    
    /// 0x64
    private func loadHIntoH() {
//        h = h
    }
    
    /// 0x65
    private func loadLIntoH() {
        h = l
    }
    
    /// 0x66
    private func loadAbsoluteHLIntoH() {
        h = mmu.readValue(address: hl)
    }
    
    /// 0x67
    private func loadAIntoH() {
        h = a
    }
    
    /// 0x68
    private func loadBIntoL() {
        l = b
    }
    
    /// 0x69
    private func loadCIntoL() {
        l = c
    }
    
    /// 0x6A
    private func loadDIntoL() {
        l = d
    }
    
    /// 0x6B
    private func loadEIntoL() {
        l = e
    }
    
    /// 0x6C
    private func loadHIntoL() {
        l = h
    }
    
    /// 0x6D
    private func loadLIntoL() {
//        l = l
    }
    
    /// 0x6E
    private func loadAbsoluteHLIntoL() {
        l = mmu.readValue(address: hl)
    }
    
    /// 0x6F
    private func loadAIntoL() {
        l = a
    }
    
    /// 0x70
    private func loadBIntoAbsoluteHL() {
        mmu.writeValue(b, address: hl)
    }
    
    /// 0x71
    private func loadCIntoAbsoluteHL() {
        mmu.writeValue(c, address: hl)
    }
    
    /// 0x72
    private func loadDIntoAbsoluteHL() {
        mmu.writeValue(d, address: hl)
    }
    
    /// 0x73
    private func loadEIntoAbsoluteHL() {
        mmu.writeValue(e, address: hl)
    }
    
    /// 0x74
    private func loadHIntoAbsoluteHL() {
        mmu.writeValue(h, address: hl)
    }
    
    /// 0x75
    private func loadLIntoAbsoluteHL() {
        mmu.writeValue(l, address: hl)
    }
    
    /// 0x76
    private func halt() {
        haltFlag = true
    }
    
    /// 0x77
    private func loadAIntoAbsoluteHL() {
        mmu.writeValue(a, address: hl)
    }
    
    /// 0x78
    private func loadBIntoA() {
        a = b
    }
    
    /// 0x79
    private func loadCIntoA() {
        a = c
    }
    
    /// 0x7A
    private func loadDIntoA() {
        a = d
    }
    
    /// 0x7B
    private func loadEIntoA() {
        a = e
    }
    
    /// 0x7C
    private func loadHIntoA() {
        a = h
    }
    
    /// 0x7D
    private func loadLIntoA() {
        a = l
    }
    
    /// 0x7E
    private func loadAbsoluteHLIntoA() {
        a = mmu.readValue(address: hl)
    }
    
    /// 0x7F
    private func loadAIntoA() {
//        a = a
    }
    
    /// 0x80
    private func addBToA() {
        a = addOperation(lhs: a, rhs: b)
    }
    
    /// 0x81
    private func addCToA() {
        a = addOperation(lhs: a, rhs: c)
    }
    
    /// 0x82
    private func addDToA() {
        a = addOperation(lhs: a, rhs: d)
    }
    
    /// 0x83
    private func addEToA() {
        a = addOperation(lhs: a, rhs: e)
    }
    
    /// 0x84
    private func addHToA() {
        a = addOperation(lhs: a, rhs: h)
    }
    
    /// 0x85
    private func addLToA() {
        a = addOperation(lhs: a, rhs: l)
    }
    
    /// 0x86
    private func addAbsoluteHLToA() {
        let value = mmu.readValue(address: hl)
        a = addOperation(lhs: a, rhs: value)
    }
    
    /// 0x87
    private func addAToA() {
        a = addOperation(lhs: a, rhs: a)
    }
    
    /// 0x88
    private func addBWithCarryToA() {
        a = addWithCarryOperation(lhs: a, rhs: b)
    }
    
    /// 0x89
    private func addCWithCarryToA() {
        a = addWithCarryOperation(lhs: a, rhs: c)
    }
    
    /// 0x8A
    private func addDWithCarryToA() {
        a = addWithCarryOperation(lhs: a, rhs: d)
    }
    
    /// 0x8B
    private func addEWithCarryToA() {
        a = addWithCarryOperation(lhs: a, rhs: e)
    }
    
    /// 0x8C
    private func addHWithCarryToA() {
        a = addWithCarryOperation(lhs: a, rhs: h)
    }
    
    /// 0x8D
    private func addLWithCarryToA() {
        a = addWithCarryOperation(lhs: a, rhs: l)
    }
    
    /// 0x8E
    private func addAbsoluteHLWithCarryToA() {
        let value = mmu.readValue(address: hl)
        a = addWithCarryOperation(lhs: a, rhs: value)
    }
    
    /// 0x8F
    private func addAWithCarryToA() {
        a = addWithCarryOperation(lhs: a, rhs: a)
    }
    
    /// 0x90
    private func subtractBFromA() {
        a = subtractOperation(lhs: a, rhs: b)
    }
    
    /// 0x91
    private func subtractCFromA() {
        a = subtractOperation(lhs: a, rhs: c)
    }
    
    /// 0x92
    private func subtractDFromA() {
        a = subtractOperation(lhs: a, rhs: d)
    }
    
    /// 0x93
    private func subtractEFromA() {
        a = subtractOperation(lhs: a, rhs: e)
    }
    
    /// 0x94
    private func subtractHFromA() {
        a = subtractOperation(lhs: a, rhs: h)
    }
    
    /// 0x95
    private func subtractLFromA() {
        a = subtractOperation(lhs: a, rhs: l)
    }
    
    /// 0x96
    private func subtractAbsoluteHLFromA() {
        let value = mmu.readValue(address: hl)
        a = subtractOperation(lhs: a, rhs: value)
    }
    
    /// 0x97
    private func subtractAFromA() {
        a = subtractOperation(lhs: a, rhs: a)
    }
    
    /// 0x98
    private func subtractBWithCarryFromA() {
        a = subtractWithCarryOperation(lhs: a, rhs: b)
    }
    
    /// 0x99
    private func subtractCWithCarryFromA() {
        a = subtractWithCarryOperation(lhs: a, rhs: c)
    }
    
    /// 0x9A
    private func subtractDWithCarryFromA() {
        a = subtractWithCarryOperation(lhs: a, rhs: d)
    }
    
    /// 0x9B
    private func subtractEWithCarryFromA() {
        a = subtractWithCarryOperation(lhs: a, rhs: e)
    }
    
    /// 0x9C
    private func subtractHWithCarryFromA() {
        a = subtractWithCarryOperation(lhs: a, rhs: h)
    }
    
    /// 0x9D
    private func subtractLWithCarryFromA() {
        a = subtractWithCarryOperation(lhs: a, rhs: l)
    }
    
    /// 0x9E
    private func subtractAbsoluteHLWithCarryFromA() {
        let value = mmu.readValue(address: hl)
        a = subtractWithCarryOperation(lhs: a, rhs: value)
    }
    
    /// 0x9F
    private func subtractAWithCarryFromA() {
        a = subtractWithCarryOperation(lhs: a, rhs: a)
    }
    
    /// 0xA0
    private func logicalAndBToA() {
        a = logicalAndOperation(lhs: a, rhs: b)
    }
    
    /// 0xA1
    private func logicalAndCToA() {
        a = logicalAndOperation(lhs: a, rhs: c)
    }
    
    /// 0xA2
    private func logicalAndDToA() {
        a = logicalAndOperation(lhs: a, rhs: d)
    }
    
    /// 0xA3
    private func logicalAndEToA() {
        a = logicalAndOperation(lhs: a, rhs: e)
    }
    
    /// 0xA4
    private func logicalAndHToA() {
        a = logicalAndOperation(lhs: a, rhs: h)
    }
    
    /// 0xA5
    private func logicalAndLToA() {
        a = logicalAndOperation(lhs: a, rhs: l)
    }
    
    /// 0xA6
    private func logicalAndAbsoluteHLToA() {
        let value = mmu.readValue(address: hl)
        a = logicalAndOperation(lhs: a, rhs: value)
    }
    
    /// 0xA7
    private func logicalAndAToA() {
        a = logicalAndOperation(lhs: a, rhs: a)
    }
    
    /// 0xA8
    private func logicalXorBToA() {
        a = logicalXorOperation(lhs: a, rhs: b)
    }
    
    /// 0xA9
    private func logicalXorCToA() {
        a = logicalXorOperation(lhs: a, rhs: c)
    }
    
    /// 0xAA
    private func logicalXorDToA() {
        a = logicalXorOperation(lhs: a, rhs: d)
    }
    
    /// 0xAB
    private func logicalXorEToA() {
        a = logicalXorOperation(lhs: a, rhs: e)
    }
    
    /// 0xAC
    private func logicalXorHToA() {
        a = logicalXorOperation(lhs: a, rhs: h)
    }
    
    /// 0xAD
    private func logicalXorLToA() {
        a = logicalXorOperation(lhs: a, rhs: l)
    }
    
    /// 0xAE
    private func logicalXorAbsoluteHLToA() {
        let value = mmu.readValue(address: hl)
        a = logicalXorOperation(lhs: a, rhs: value)
    }

    /// 0xAF
    private func logicalXorAToA() {
        a = logicalXorOperation(lhs: a, rhs: a)
    }
    
    /// 0xB0
    private func logicalOrBToA() {
        a = logicalOrOperation(lhs: a, rhs: b)
    }
    
    /// 0xB1
    private func logicalOrCToA() {
        a = logicalOrOperation(lhs: a, rhs: c)
    }
    
    /// 0xB2
    private func logicalOrDToA() {
        a = logicalOrOperation(lhs: a, rhs: d)
    }
    
    /// 0xB3
    private func logicalOrEToA() {
        a = logicalOrOperation(lhs: a, rhs: e)
    }
    
    /// 0xB4
    private func logicalOrHToA() {
        a = logicalOrOperation(lhs: a, rhs: h)
    }
    
    /// 0xB5
    private func logicalOrLToA() {
        a = logicalOrOperation(lhs: a, rhs: l)
    }
    
    /// 0xB6
    private func logicalOrAbsoluteHLToA() {
        let value = mmu.readValue(address: hl)
        a = logicalOrOperation(lhs: a, rhs: value)
    }
    
    /// 0xB7
    private func logicalOrAToA() {
        a = logicalOrOperation(lhs: a, rhs: a)
    }
    
    /// 0xB8
    private func compareBToA() {
        compare(a, to: b)
    }
    
    /// 0xB9
    private func compareCToA() {
        compare(a, to: c)
    }
    
    /// 0xBA
    private func compareDToA() {
        compare(a, to: d)
    }
    
    /// 0xBB
    private func compareEToA() {
        compare(a, to: e)
    }
    
    /// 0xBC
    private func compareHToA() {
        compare(a, to: h)
    }
    
    /// 0xBD
    private func compareLToA() {
        compare(a, to: l)
    }
    
    /// 0xBE
    private func compareAbsoluteHLToA() {
        let value = mmu.readValue(address: hl)
        compare(a, to: value)
    }

    /// 0xBF
    private func compareAToA() {
        compare(a, to: a)
    }
    
    /// 0xC0
    private func returnIfZFlagCleared() {
        if !zFlag {
            pc = popStack()
        }
    }
    
    /// 0xC1
    private func popStackIntoBC() {
        bc = popStack()
    }
    
    /// 0xC2
    private func absoluteJumpIfZFlagCleared() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        if !zFlag {
            pc = address
        }
    }
    
    /// 0xC3
    private func unconditionalAbsoluteJump() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        pc = address
    }
    
    /// 0xC4
    private func callIfZFlagCleared() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        if !zFlag {
            pushOntoStack(address: pc)
            pc = address
        }
    }
    
    /// 0xC5
    private func pushBCOntoStack() {
        pushOntoStack(address: bc)
    }
    
    /// 0xC6
    private func addByteToA() {
        a = addOperation(lhs: a, rhs: fetchNextByte())
    }
    
    /// 0xC7
    private func resetToByte0() {
        pushOntoStack(address: pc)
        pc = UInt16(bytes: [0x00, 0x00])!
    }
    
    /// 0xC8
    private func returnIfZFlagSet() {
        if zFlag {
            pc = popStack()
        }
    }
    
    /// 0xC9
    private func unconditionalReturn() {
        pc = popStack()
    }
    
    /// 0xCA
    private func absoluteJumpIfZFlagSet() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        if zFlag {
            pc = address
        }
    }
    
    /// 0xCC
    private func callIfZFlagSet() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        if zFlag {
            pushOntoStack(address: pc)
            pc = address
        }
    }
    
    /// 0xCD
    private func unconditionalCall() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        pushOntoStack(address: pc)
        pc = address
    }
    
    /// 0xCE
    private func addByteWithCarryToA() {
        let byte = fetchNextByte()
        a = addWithCarryOperation(lhs: a, rhs: byte)
    }
    
    /// 0xCF
    private func resetToByte1() {
        pushOntoStack(address: pc)
        pc = UInt16(bytes: [0x08, 0x00])!
    }
    
    /// 0xD0
    private func returnIfCFlagCleared() {
        if !cFlag {
            pc = popStack()
        }
    }
    
    /// 0xD1
    private func popStackIntoDE() {
        de = popStack()
    }
    
    /// 0xD2
    private func absoluteJumpIfCFlagCleared() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        if !cFlag {
            pc = address
        }
    }
    
    /// 0xD4
    private func callIfCFlagCleared() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        if !cFlag {
            pushOntoStack(address: pc)
            pc = address
        }
    }
    
    /// 0xD5
    private func pushDEOntoStack() {
        pushOntoStack(address: de)
    }
    
    /// 0xD6
    private func subtractByteFromA() {
        a = subtractOperation(lhs: a, rhs: fetchNextByte())
    }
    
    /// 0xD7
    private func resetToByte2() {
        pushOntoStack(address: pc)
        pc = UInt16(bytes: [0x10, 0x00])!
    }
    
    /// 0xD8
    private func returnIfCFlagSet() {
        if cFlag {
            pc = popStack()
        }
    }
    
    /// 0xD9
    private func unconditionalReturnWithInterrupt() {
        pc = popStack()
        imeFlag = true
    }
    
    /// 0xDA
    private func absoluteJumpIfCFlagSet() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        if cFlag {
            pc = address
        }
    }
    
    /// 0xDC
    private func callIfCFlagSet() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        if cFlag {
            pushOntoStack(address: pc)
            pc = address
        }
    }
    
    /// 0xDE
    private func subtractByteWithCarryToA() {
        let byte = fetchNextByte()
        a = subtractWithCarryOperation(lhs: a, rhs: byte)
    }
    
    /// 0xDF
    private func resetToByte3() {
        pushOntoStack(address: pc)
        pc = UInt16(bytes: [0x18, 0x00])!
    }
    
    /// 0xE0
    private func highPageLoadAIntoByteAddress() {
        let lowerByte = fetchNextByte()
        let address = UInt16(bytes: [lowerByte, 0xFF])!
        mmu.writeValue(a, address: address)
    }
    
    /// 0xE1
    private func popStackIntoHL() {
        hl = popStack()
    }
    
    /// 0xE2
    private func highPageLoadAIntoAbsoluteC() {
        let address = UInt16(bytes: [c, 0xFF])!
        mmu.writeValue(a, address: address)
    }
    
    /// 0xE5
    private func pushHLOntoStack() {
        pushOntoStack(address: hl)
    }
    
    /// 0xE6
    private func logicalAndByteToA() {
        let byte = fetchNextByte()
        a = logicalAndOperation(lhs: a, rhs: byte)
    }
    
    /// 0xE7
    private func resetToByte4() {
        pushOntoStack(address: pc)
        pc = UInt16(bytes: [0x20, 0x00])!
    }
    
    /// 0xE8
    private func addByteToSP() {
        let signedByte = Int8(bitPattern: fetchNextByte())
        sp = addOperation(lhs: sp, rhs: signedByte)
    }
    
    /// 0xE9
    private func jumpToHL() {
        pc = hl
    }
    
    /// 0xEA
    private func loadAIntoShortAddress() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        mmu.writeValue(a, address: address)
    }
    
    /// 0xEE
    private func logicalXorByteToA() {
        a = logicalXorOperation(lhs: a, rhs: fetchNextByte())
    }
    
    /// 0xEF
    private func resetToByte5() {
        pushOntoStack(address: pc)
        pc = UInt16(bytes: [0x28, 0x00])!
    }
    
    /// 0xF0
    private func highPageLoadAbsoluteByteAddressIntoA() {
        let lowerByte = fetchNextByte()
        let address = UInt16(bytes: [lowerByte, 0xFF])!
        a = mmu.readValue(address: address)
    }
    
    /// 0xF1
    private func popStackIntoAF() {
        af = popStack()
    }
    
    /// 0xF2
    private func highPageLoadAbsoluteCIntoA() {
        let address = UInt16(bytes: [c, 0xFF])!
        a = mmu.readValue(address: address)
    }
    
    /// 0xF3
    private func disableInterruptHandling() {
        imeFlag = false
    }
    
    /// 0xF5
    private func pushAFOntoStack() {
        pushOntoStack(address: af)
    }
    
    /// 0xF6
    private func logicalOrByteToA() {
        let byte = fetchNextByte()
        a = logicalOrOperation(lhs: a, rhs: byte)
    }
    
    /// 0xF7
    private func resetToByte6() {
        pushOntoStack(address: pc)
        pc = UInt16(bytes: [0x30, 0x00])!
    }
    
    /// 0xF8
    private func loadSPPlusByteIntoHL() {
        let signedByte = Int8(bitPattern: fetchNextByte())
        hl = addOperation(lhs: sp, rhs: signedByte)
    }
    
    /// 0xF9
    private func loadHLIntoSP() {
        sp = hl
    }
    
    /// 0xFA
    private func loadAbsoluteShortAddressIntoA() {
        let address = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        a = mmu.readValue(address: address)
    }
    
    /// 0xFB
    private func scheduleInterruptHandling() {
        imeFlag = true
        // TODO: Should this use a imeScheduledFlag instead?
    }
    
    /// 0xFE
    private func compareByteToA() {
        compare(a, to: fetchNextByte())
    }
    
    /// 0xFF
    private func resetToByte7() {
        pushOntoStack(address: pc)
        pc = UInt16(bytes: [0x38, 0x00])!
    }
}

// MARK: - 16-bit Instructions (Opcodes with 0xCB prefix)

extension CPU {
    
    private func execute16BitInstruction() {
        let opcode = fetchNextByte()
        
        switch opcode {
        
        case 0x00...0x07: // Rotate left with carry
            let oldRegisterValue = getRegisterValueForOpcode(opcode)
            let newRegisterValue = oldRegisterValue.bitwiseLeftRotation(amount: 1)
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(7)
            
        case 0x08...0x0F: // Rotate right with carry
            let oldRegisterValue = getRegisterValueForOpcode(opcode)
            let newRegisterValue = oldRegisterValue.bitwiseRightRotation(amount: 1)
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(0)
            
        case 0x10...0x17: // Rotate left
            let oldRegisterValue = getRegisterValueForOpcode(opcode)
            var newRegisterValue = oldRegisterValue.bitwiseLeftRotation(amount: 1)
            cFlag ? newRegisterValue.setBit(0) : newRegisterValue.clearBit(0)
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(7)
            
        case 0x18...0x1F: // Rotate right
            let oldRegisterValue = getRegisterValueForOpcode(opcode)
            var newRegisterValue = oldRegisterValue.bitwiseRightRotation(amount: 1)
            cFlag ? newRegisterValue.setBit(7) : newRegisterValue.clearBit(7)
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(0)
            
        case 0x20...0x27: // Shift left arithmetic
            let oldRegisterValue = getRegisterValueForOpcode(opcode)
            let newRegisterValue = oldRegisterValue << 1
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(7)
            
        case 0x28...0x2F: // Shift right arithmetic
            let oldRegisterValue = getRegisterValueForOpcode(opcode)
            var newRegisterValue = oldRegisterValue >> 1
            oldRegisterValue.checkBit(7) ? newRegisterValue.setBit(7) : newRegisterValue.clearBit(0)
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(0)
            
        case 0x30...0x37: // Swap nibbles
            let oldRegisterValue = getRegisterValueForOpcode(opcode)
            let newRegisterValue = (oldRegisterValue.lowNibble << 4) | oldRegisterValue.highNibble
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = false
            
        case 0x38...0x3F: // Shift right logical
            let oldRegisterValue = getRegisterValueForOpcode(opcode)
            let newRegisterValue = oldRegisterValue >> 1
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(0)
            
        case 0x40...0x7F: // Check bit
            let relativeOpcode = opcode - 0x40
            let bitIndex = Int(relativeOpcode / 8)
            let registerValue = getRegisterValueForOpcode(opcode)
            let isBitSet = registerValue.checkBit(bitIndex)
            zFlag = !isBitSet
            nFlag = false
            hFlag = false
            
        case 0x80...0xBF: // Reset bit
            let relativeOpcode = opcode - 0x80
            let bitIndex = Int(relativeOpcode / 8)
            var registerValue = getRegisterValueForOpcode(opcode)
            registerValue.clearBit(bitIndex)
            setRegisterValueForOpcode(opcode, value: registerValue)
            
        case 0xC0...0xFF: // Set bit
            let relativeOpcode = opcode - 0xC0
            let bitIndex = Int(relativeOpcode / 8)
            var registerValue = getRegisterValueForOpcode(opcode)
            registerValue.setBit(bitIndex)
            setRegisterValueForOpcode(opcode, value: registerValue)
            
        default: fatalError("Unhandled opcode found. Got \(opcode).")
        }
    }
}

// MARK: - Convenience

extension CPU {
    
    private func fetchNextByte() -> UInt8 {
        let opcode = mmu.readValue(address: pc)
        pc &+= 1
        return opcode
    }
    
    private func popStack() -> UInt16 {
        let lowerByte = mmu.readValue(address: sp)
        sp &+= 1
        let upperByte = mmu.readValue(address: sp)
        sp &+= 1
        return UInt16(bytes: [lowerByte, upperByte])!
    }
    
    private func pushOntoStack(address: UInt16) {
        let bytes = address.asBytes()
        let lowerByte = bytes[0]
        let upperByte = bytes[1]
        
        sp &-= 1
        mmu.writeValue(upperByte, address: sp)
        sp &-= 1
        mmu.writeValue(lowerByte, address: sp)
    }
    
    /// Parts of the opcode tables are organised in a way where the high nibble is the function
    /// and the low nibble is the register parameter.
    private func getRegisterValueForOpcode(_ opcode: UInt8) -> UInt8 {
        switch opcode.lowNibble {
        case 0x0, 0x8: return b
        case 0x1, 0x9: return c
        case 0x2, 0xA: return d
        case 0x3, 0xB: return e
        case 0x4, 0xC: return h
        case 0x5, 0xD: return l
        case 0x6, 0xE: return mmu.readValue(address: hl)
        case 0x7, 0xF: return a
        default: fatalError()
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
        case 0x6, 0xE: mmu.writeValue(value, address: hl)
        case 0x7, 0xF: a = value
        default: fatalError()
        }
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
    
    private func addOperation(lhs: UInt8, rhs: UInt8) -> UInt8 {
        let (value, carry) = lhs.addingReportingOverflow(rhs)
        let (_, halfCarry) = lhs.addingReportingHalfCarry(rhs)
        
        zFlag = value == 0
        nFlag = false
        hFlag = halfCarry
        cFlag = carry
        
        return value
    }
    
    private func addWithCarryOperation(lhs: UInt8, rhs: UInt8) -> UInt8 {
        let carryBit: UInt8 = cFlag ? 1 : 0
        return addOperation(lhs: lhs, rhs: rhs &+ carryBit)
    }
    
    private func addOperation(lhs: UInt16, rhs: UInt16) -> UInt16 {
        // Ref: https://stackoverflow.com/a/57981912
        let lhsBytes = lhs.asBytes()
        let rhsBytes = rhs.asBytes()
        
        let lowerByte = addOperation(lhs: lhsBytes[0], rhs: rhsBytes[0])
        let upperByte = addWithCarryOperation(lhs: lhsBytes[1], rhs: rhsBytes[1])
        
        return UInt16(bytes: [lowerByte, upperByte])!
    }
    
    private func addOperation(lhs: UInt16, rhs: Int8) -> UInt16 {
        let isPositive = rhs >= 0
        let magnitude = rhs.magnitude
        
        if isPositive {
            let (lowerByte, carry) = lhs.asBytes()[0].addingReportingOverflow(magnitude)
            let (_, halfCarry) = lhs.asBytes()[0].addingReportingHalfCarry(magnitude)
            let carryBit: UInt8 = carry ? 1 : 0
            let upperByte = lhs.asBytes()[1] &+ carryBit
            let value = UInt16(bytes: [lowerByte, upperByte])!
            
            zFlag = false
            nFlag = false
            hFlag = halfCarry
            cFlag = carry
            return value
        } else {
            let (lowerByte, carry) = lhs.asBytes()[0].subtractingReportingOverflow(magnitude)
            let (_, halfCarry) = lhs.asBytes()[0].subtractingReportingHalfCarry(magnitude)
            let carryBit: UInt8 = carry ? 1 : 0
            let upperByte = lhs.asBytes()[1] &- carryBit
            let value = UInt16(bytes: [lowerByte, upperByte])!
            
            zFlag = false
            nFlag = false
            hFlag = halfCarry
            cFlag = carry
            return value
        }
    }
    
    private func subtractOperation(lhs: UInt8, rhs: UInt8) -> UInt8 {
        let (value, carry) = lhs.subtractingReportingOverflow(rhs)
        let (_, halfCarry) = lhs.subtractingReportingHalfCarry(rhs)
        
        zFlag = value == 0
        nFlag = true
        hFlag = halfCarry
        cFlag = carry
        
        return value
    }
    
    private func subtractWithCarryOperation(lhs: UInt8, rhs: UInt8) -> UInt8 {
        let carryBit: UInt8 = cFlag ? 1 : 0
        return subtractOperation(lhs: lhs, rhs: rhs &- carryBit)
    }
    
    private func logicalAndOperation(lhs: UInt8, rhs: UInt8) -> UInt8 {
        let value = lhs & rhs
        
        zFlag = value == 0
        nFlag = false
        hFlag = true
        cFlag = false
        
        return value
    }
    
    private func logicalXorOperation(lhs: UInt8, rhs: UInt8) -> UInt8 {
        let value = lhs ^ rhs
        
        zFlag = value == 0
        nFlag = false
        hFlag = false
        cFlag = false
        
        return value
    }
    
    private func logicalOrOperation(lhs: UInt8, rhs: UInt8) -> UInt8 {
        let value = lhs | rhs
        
        zFlag = value == 0
        nFlag = false
        hFlag = false
        cFlag = false
        
        return value
    }
    
    private func compare(_ lhs: UInt8, to rhs: UInt8) {
        let (comparison, carry) = lhs.subtractingReportingOverflow(rhs)
        let (_, halfCarry) = lhs.subtractingReportingHalfCarry(rhs)
        
        zFlag = comparison == 0
        nFlag = true
        hFlag = halfCarry
        cFlag = carry
    }
    
    private func relativeJump(byte: UInt8) {
        let isPositive = Int8(bitPattern: byte) >= 0
        
        let offsetMagnitude = UInt16(byte)
        if isPositive {
            pc &+= offsetMagnitude
        } else {
            pc &-= offsetMagnitude
        }
    }
}
