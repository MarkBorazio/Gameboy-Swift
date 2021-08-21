//
//  CPU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

class CPU {
    
    let memory = Memory()
    
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
            
        case 0x10: stop()
        case 0x11: loadShortIntoDE()
        case 0x12: loadAIntoAbsoluteDE()
        case 0x13: incrementDE()
        case 0x14: incrementD()
        case 0x15: decrementD()
        case 0x16: loadByteIntoD()
        case 0x17: rotateALeftThroughCarry()
        case 0x18: unconditionalJump()
        case 0x19: addDEtoHL()
        case 0x1A: loadAbsoluteDEIntoA()
        case 0x1B: decrementDE()
        case 0x1C: incrementE()
        case 0x1D: decrementE()
        case 0x1E: loadByteIntoE()
        case 0x1F: rotateARightThroughCarry()
            
        case 0x20: jumpIfZFlagCleared()
        case 0x21: loadShortIntoHL()
        case 0x22: loadAIntoAbsoluteHLAndIncrementHL()
        case 0x23: incrementHL()
        case 0x24: incrementH()
        case 0x25: decrementH()
        case 0x26: loadByteIntoH()
        case 0x27: decimalAdjustAfterAddition()
        case 0x28: jumpIfZFlagSet()
        case 0x29: addHLtoHL()
        case 0x2A: loadAbsoluteHLIntoAAndIncrementHL()
        case 0x2B: decrementHL()
        case 0x2C: incrementL()
        case 0x2D: decrementL()
        case 0x2E: loadByteIntoL()
        case 0x2F: flipBitsInA()
            
        case 0x30: jumpIfCFlagCleared()
        case 0x31: loadShortIntoSP()
        case 0x32: loadAIntoAbsoluteHLAndDecrementHL()
        case 0x33: incrementSP()
        case 0x34: incrementAbsoluteHL()
        case 0x35: decrementAbsoluteHL()
        case 0x36: loadByteIntoAbsoluteHL()
        case 0x37: setCFlag()
        case 0x38: jumpIfCFlagSet()
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
            
        default: fatalError("Encountered unknown opcode.")
        }
    }
    
    private func fetchNextByte() -> UInt8 {
        let opcode = memory.readValue(address: pc)
        pc &+= 1
        return opcode
    }
}

// MARK: - 8-bit Instructions

extension CPU {
    
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
        memory.writeValue(a, address: bc)
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
        memory.writeValue(sp.asBytes()[0], address: address)
        memory.writeValue(sp.asBytes()[1], address: address+1)
    }
    
    /// 0x09
    private func addBCtoHL() {
        hl = addOperation(lhs: hl, rhs: bc)
    }
    
    /// 0x0A
    private func loadAbsoluteBCIntoA() {
        a = memory.readValue(address: bc)
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
        fatalError("TODO: Implement STOP instruction.")
        // TODO: This
        // Also, figure out if this is a 2 byte operation.
    }
    
    /// 0x11
    private func loadShortIntoDE() {
        let value = UInt16(bytes: [fetchNextByte(), fetchNextByte()])!
        de = value
    }
    
    /// 0x12
    private func loadAIntoAbsoluteDE() {
        memory.writeValue(a, address: de)
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
    private func unconditionalJump() {
        relativeJump(byte: fetchNextByte())
    }
    
    /// 0x19
    private func addDEtoHL() {
        hl = addOperation(lhs: hl, rhs: de)
    }
    
    /// 0x1A
    private func loadAbsoluteDEIntoA() {
        a = memory.readValue(address: de)
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
    private func jumpIfZFlagCleared() {
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
        memory.writeValue(a, address: hl)
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
    private func jumpIfZFlagSet() {
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
        a = memory.readValue(address: hl)
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
    private func jumpIfCFlagCleared() {
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
        memory.writeValue(a, address: hl)
        hl -= 1
    }
    
    /// 0x33
    private func incrementSP() {
        sp &+= 1
    }
    
    /// 0x34
    private func incrementAbsoluteHL() {
        let value = memory.readValue(address: hl)
        let incrementedValue = incrementOperation(value)
        memory.writeValue(incrementedValue, address: hl)
    }
    
    /// 0x35
    private func decrementAbsoluteHL() {
        let value = memory.readValue(address: hl)
        let decrementedValue = decrementOperation(value)
        memory.writeValue(decrementedValue, address: hl)
    }
    
    /// 0x36
    private func loadByteIntoAbsoluteHL() {
        let byte = fetchNextByte()
        memory.writeValue(byte, address: hl)
    }
    
    /// 0x37
    private func setCFlag() {
        cFlag = true
        // Also need to clear n and h flags
        nFlag = false
        hFlag = false
    }
    
    /// 0x38
    private func jumpIfCFlagSet() {
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
        a = memory.readValue(address: hl)
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
        b = memory.readValue(address: hl)
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
        c = memory.readValue(address: hl)
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
        d = memory.readValue(address: hl)
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
        e = memory.readValue(address: hl)
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
        h = memory.readValue(address: hl)
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
        l = memory.readValue(address: hl)
    }
    
    /// 0x6F
    private func loadAIntoL() {
        l = a
    }
    
    /// 0x70
    private func loadBIntoAbsoluteHL() {
        memory.writeValue(b, address: hl)
    }
    
    /// 0x71
    private func loadCIntoAbsoluteHL() {
        memory.writeValue(c, address: hl)
    }
    
    /// 0x72
    private func loadDIntoAbsoluteHL() {
        memory.writeValue(d, address: hl)
    }
    
    /// 0x73
    private func loadEIntoAbsoluteHL() {
        memory.writeValue(e, address: hl)
    }
    
    /// 0x74
    private func loadHIntoAbsoluteHL() {
        memory.writeValue(h, address: hl)
    }
    
    /// 0x75
    private func loadLIntoAbsoluteHL() {
        memory.writeValue(l, address: hl)
    }
    
    /// 0x76
    private func halt() {
        fatalError("TODO: Implement HALT instruction.")
    }
    
    /// 0x77
    private func loadAIntoAbsoluteHL() {
        memory.writeValue(a, address: hl)
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
        a = memory.readValue(address: hl)
    }
    
    /// 0x7F
    private func loadAIntoA() {
//        a = a
    }
}


// MARK: - Convenience

extension CPU {
    
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
        let (summation, carry) = lhs.addingReportingOverflow(rhs)
        let (_, halfCarry) = lhs.addingReportingHalfCarry(rhs)
        
        zFlag = summation == 0
        nFlag = false
        hFlag = halfCarry
        cFlag = carry
        
        return summation
    }
    
    private func addOperation(lhs: UInt16, rhs: UInt16) -> UInt16 {
        // Ref: https://stackoverflow.com/a/57981912
        let lhsBytes = lhs.asBytes()
        let rhsBytes = rhs.asBytes()
        
        let lowerByte = addOperation(lhs: lhsBytes[0], rhs: rhsBytes[0])
        let carryBit: UInt8 = cFlag ? 1 : 0
        let upperByte = addOperation(lhs: lhsBytes[1], rhs: rhsBytes[1] &+ carryBit)
        
        return UInt16(bytes: [lowerByte, upperByte])!
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
