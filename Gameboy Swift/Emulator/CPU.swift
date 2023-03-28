//
//  CPU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

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
    private func executeInstruction() -> Int {
        let opcode = fetchNextByte()
        if opcode == 0xCB {
            execute16BitInstruction()
        } else {
            execute8BitInstruction(opcode: opcode)
        }
    }
    
    func handleInterrupts() {
        if imeFlag { // Is master interrupt enable flag set?
            if let interruptAddress = MMU.shared.checkForInterrupt() {
                imeFlag = false
                pushOntoStack(address: pc)
                pc = interruptAddress
            }
        }
    }
    
    private func fetchNextByte() -> UInt8 {
        let opcode = MMU.shared.readValue(address: pc)
        pc &+= 1
        return opcode
    }
}

// MARK: - 8-bit Instructions

extension CPU {
    
    /// Execute the instruction from the opcode and returns the number of cycles it took.
    private func execute8BitInstruction(opcode: UInt8) -> Int {
        switch opcode {
        case 0x00: return noOp()
        case 0x01: return loadImmediateShortIntoPair(&bc)
        case 0x02: return loadAccumulatorIntoPair(&bc)
        case 0x03: return incrementPair(&bc)
        case 0x04: return incrementRegister(&b)
        case 0x05: return decrementRegister(&b)
        case 0x06: return loadImmediateByteIntoRegister(&b)
        case 0x07: return rotateALeftWithCarry()
        case 0x08: return loadSPIntoAddress()
        case 0x09: return addToHL(bc)
        case 0x0A: return loadPointeeIntoA(pointer: bc)
        case 0x0B: return decrementPair(&bc)
        case 0x0C: return incrementRegister(&c)
        case 0x0D: return decrementRegister(&c)
        case 0x0E: return loadImmediateByteIntoRegister(&c)
        case 0x0F: return rotateARightWithCarry()
            
        case 0x10: stop()
        case 0x11: loadImmediateShortIntoPair(opcode: opcode)
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
        case 0x21: loadImmediateShortIntoPair(opcode: opcode)
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
        case 0x31: loadImmediateShortIntoPair(opcode: opcode)
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
            
        // Middle Of Table
        case 0x40...0x75: loadOperation(opcode: opcode)
        case 0x76: halt()
        case 0x77...0x7F: loadOperation(opcode: opcode)
        case 0x80...0x87: a = addOperation(lhs: a, rhs: getRegisterByte(opcode: opcode))
        case 0x88...0x8F: a = addWithCarryOperation(lhs: a, rhs: getRegisterByte(opcode: opcode))
        case 0x90...0x97: a = subtractOperation(lhs: a, rhs: getRegisterByte(opcode: opcode))
        case 0x98...0x9F: a = subtractWithCarryOperation(lhs: a, rhs: getRegisterByte(opcode: opcode))
        case 0xA0...0xA7: a = logicalAndOperation(lhs: a, rhs: getRegisterByte(opcode: opcode))
        case 0xA8...0xAF: a = logicalXorOperation(lhs: a, rhs: getRegisterByte(opcode: opcode))
        case 0xB0...0xB7: a = logicalOrOperation(lhs: a, rhs: getRegisterByte(opcode: opcode))
        case 0xB8...0xBF: compare(a, to: getRegisterByte(opcode: opcode))
            
        case 0xC0: returnIfZFlagCleared()
        case 0xC1: popStackIntoBC()
        case 0xC2: absoluteJumpIfZFlagCleared()
        case 0xC3: unconditionalAbsoluteJump()
        case 0xC4: callIfZFlagCleared()
        case 0xC5: pushOntoStack(address: bc)
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
        case 0xD5: pushOntoStack(address: de)
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
        case 0xE5: pushOntoStack(address: hl)
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
        case 0xF5: pushOntoStack(address: af)
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
            
        default: fatalError("Encountered unknown 8-bit opcode: \(opcode).")
        }
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
    
    /// 0x12
    private func loadAIntoAbsoluteDE() {
        MMU.shared.writeValue(a, address: de)
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
        a = MMU.shared.readValue(address: de)
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
    
    /// 0x22
    private func loadAIntoAbsoluteHLAndIncrementHL() {
        MMU.shared.writeValue(a, address: hl)
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
        a = MMU.shared.readValue(address: hl)
        hl &+= 1
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
    
    /// 0x32
    private func loadAIntoAbsoluteHLAndDecrementHL() {
        MMU.shared.writeValue(a, address: hl)
        hl -= 1
    }
    
    /// 0x33
    private func incrementSP() {
        sp &+= 1
    }
    
    /// 0x34
    private func incrementAbsoluteHL() {
        let value = MMU.shared.readValue(address: hl)
        let incrementedValue = incrementOperation(value)
        MMU.shared.writeValue(incrementedValue, address: hl)
    }
    
    /// 0x35
    private func decrementAbsoluteHL() {
        let value = MMU.shared.readValue(address: hl)
        let decrementedValue = decrementOperation(value)
        MMU.shared.writeValue(decrementedValue, address: hl)
    }
    
    /// 0x36
    private func loadByteIntoAbsoluteHL() {
        let byte = fetchNextByte()
        MMU.shared.writeValue(byte, address: hl)
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
        a = MMU.shared.readValue(address: hl)
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
    
    /// 0x76
    private func halt() {
        haltFlag = true
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
        MMU.shared.writeValue(a, address: address)
    }
    
    /// 0xE1
    private func popStackIntoHL() {
        hl = popStack()
    }
    
    /// 0xE2
    private func highPageLoadAIntoAbsoluteC() {
        let address = UInt16(bytes: [c, 0xFF])!
        MMU.shared.writeValue(a, address: address)
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
        MMU.shared.writeValue(a, address: address)
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
        a = MMU.shared.readValue(address: address)
    }
    
    /// 0xF1
    private func popStackIntoAF() {
        af = popStack()
    }
    
    /// 0xF2
    private func highPageLoadAbsoluteCIntoA() {
        let address = UInt16(bytes: [c, 0xFF])!
        a = MMU.shared.readValue(address: address)
    }
    
    /// 0xF3
    private func disableInterruptHandling() {
        imeFlag = false
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
        a = MMU.shared.readValue(address: address)
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
    
    
    // 0x01, 0x11, 0x21, 0x31
    private func loadImmediateShortIntoPair(_ pair: inout UInt16) -> Int {
        let value = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        pair = value
        return 3
    }
    
    // 0x02, 0x12
    private func loadAccumulatorIntoPair(_ pair: inout UInt16) -> Int {
        let value = UInt16(a)
        pair = value
        return 2
    }
    
    // 0x06, 0x16, 0x26, 0x0E, 0x1E, 0x2E, 0x3E
    private func loadImmediateByteIntoRegister(_ register: inout UInt8) -> Int {
        let value = fetchNextByte()
        register = value
        return 2
    }
    
    // 0x0A, 0x1A, 0x2A, 0x3A
    private func loadPointeeIntoA(pointer: UInt16) -> Int {
        a = MMU.shared.readValue(address: pointer)
        return 2
    }
    
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
        register &+= 1
        // TODO: Update flags
        return 1
    }
    
    // 0x05, 0x15, 0x25, 0x0D, 0x1D, 0x2D, 0x3D
    private func decrementRegister(_ register: inout UInt8) -> Int {
        register &-= 1
        // TODO: Update flags
        return 1
    }
    
    // 0x09, 0x19, 0x29, 0x39
    private func addToHL(_ value: UInt16) -> Int {
        // Ref: https://stackoverflow.com/a/57981912
        _ = addOperation(lhs: &l, rhs: value.asBytes()[0])
        _ = addWithCarryOperation(lhs: &h, rhs: value.asBytes()[1])
        
        // TODO: Confirm Z flag behaviour here.
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
    
    // 0x88, 0x89, 0x8A, 0x8B, 0x8C, 0x8D, 0x8F
    private func addWithCarryOperation(lhs: inout UInt8, rhs: UInt8) -> Int {
        let carryBit: UInt8 = cFlag ? 1 : 0
        return addOperation(lhs: &lhs, rhs: rhs &+ carryBit)
    }
}

// MARK: - 16-bit Instructions (Opcodes with 0xCB prefix)

extension CPU {
    
    private func execute16BitInstruction() {
        let opcode = fetchNextByte()
        
        switch opcode {
        
        case 0x00...0x07: // Rotate left with carry
            let oldRegisterValue = getRegisterByte(opcode: opcode)
            let newRegisterValue = oldRegisterValue.bitwiseLeftRotation(amount: 1)
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(7)
            
        case 0x08...0x0F: // Rotate right with carry
            let oldRegisterValue = getRegisterByte(opcode: opcode)
            let newRegisterValue = oldRegisterValue.bitwiseRightRotation(amount: 1)
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(0)
            
        case 0x10...0x17: // Rotate left
            let oldRegisterValue = getRegisterByte(opcode: opcode)
            var newRegisterValue = oldRegisterValue.bitwiseLeftRotation(amount: 1)
            cFlag ? newRegisterValue.setBit(0) : newRegisterValue.clearBit(0)
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(7)
            
        case 0x18...0x1F: // Rotate right
            let oldRegisterValue = getRegisterByte(opcode: opcode)
            var newRegisterValue = oldRegisterValue.bitwiseRightRotation(amount: 1)
            cFlag ? newRegisterValue.setBit(7) : newRegisterValue.clearBit(7)
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(0)
            
        case 0x20...0x27: // Shift left arithmetic
            let oldRegisterValue = getRegisterByte(opcode: opcode)
            let newRegisterValue = oldRegisterValue << 1
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(7)
            
        case 0x28...0x2F: // Shift right arithmetic
            let oldRegisterValue = getRegisterByte(opcode: opcode)
            var newRegisterValue = oldRegisterValue >> 1
            oldRegisterValue.checkBit(7) ? newRegisterValue.setBit(7) : newRegisterValue.clearBit(0)
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(0)
            
        case 0x30...0x37: // Swap nibbles
            let oldRegisterValue = getRegisterByte(opcode: opcode)
            let newRegisterValue = (oldRegisterValue.lowNibble << 4) | oldRegisterValue.highNibble
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = false
            
        case 0x38...0x3F: // Shift right logical
            let oldRegisterValue = getRegisterByte(opcode: opcode)
            let newRegisterValue = oldRegisterValue >> 1
            
            setRegisterValueForOpcode(opcode, value: newRegisterValue)
            zFlag = newRegisterValue == 0
            nFlag = false
            hFlag = false
            cFlag = oldRegisterValue.checkBit(0)
            
        case 0x40...0x7F: // Check bit
            let relativeOpcode = opcode - 0x40
            let bitIndex = Int(relativeOpcode / 8)
            let registerValue = getRegisterByte(opcode: opcode)
            let isBitSet = registerValue.checkBit(bitIndex)
            zFlag = !isBitSet
            nFlag = false
            hFlag = false
            
        case 0x80...0xBF: // Reset bit
            let relativeOpcode = opcode - 0x80
            let bitIndex = Int(relativeOpcode / 8)
            var registerValue = getRegisterByte(opcode: opcode)
            registerValue.clearBit(bitIndex)
            setRegisterValueForOpcode(opcode, value: registerValue)
            
        case 0xC0...0xFF: // Set bit
            let relativeOpcode = opcode - 0xC0
            let bitIndex = Int(relativeOpcode / 8)
            var registerValue = getRegisterByte(opcode: opcode)
            registerValue.setBit(bitIndex)
            setRegisterValueForOpcode(opcode, value: registerValue)
            
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
    
    private func pushOntoStack(address: UInt16) {
        let bytes = address.asBytes()
        let lowerByte = bytes[0]
        let upperByte = bytes[1]
        
        sp &-= 1
        MMU.shared.writeValue(upperByte, address: sp)
        sp &-= 1
        MMU.shared.writeValue(lowerByte, address: sp)
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
    
    private func loadOperation(opcode: UInt8) {
        let valueToSet = getRegisterByte(opcode: opcode)
        
        switch opcode {
        case 0x40...0x47: b = valueToSet
        case 0x48...0x4F: c = valueToSet
        case 0x50...0x57: d = valueToSet
        case 0x58...0x5F: e = valueToSet
        case 0x60...0x67: h = valueToSet
        case 0x68...0x6F: l = valueToSet
        case 0x70...0x75, 0x77: MMU.shared.writeValue(valueToSet, address: hl)
        case 0x78...0x7F: a = valueToSet
        default: fatalError("Failed to SET value in load operation using opcode: \(opcode)")
        }
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
