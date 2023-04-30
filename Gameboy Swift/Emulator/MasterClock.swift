//
//  MasterClock.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 26/3/2023.
//

import Foundation
import Cocoa

class MasterClock {
    
    static let shared = MasterClock()
    
    weak var screenRenderDelegate: ScreenRenderDelegate?
    
    var timer: Timer?
    let timerQueue = DispatchQueue(label: "timerQueue")
    
    private static let framesPerSecond: UInt32 = 60
    
    static let tCyclesHz: UInt32 = 4194304
    static let mCyclesHz: UInt32 = tCyclesHz / 4
    private static let machineCyclesCyclesPerFrame: UInt32 = mCyclesHz / framesPerSecond
    private static let timerInterval: TimeInterval = 1.0 / Double(framesPerSecond)
    
    private var cycles: Int = 0
    private var timaTimer: Int = 0
    
    private var internalDivCounter: UInt8 = 0
    private var divRegister: UInt8 = 0
    
    func startTicking() {
        self.timer = Timer.scheduledTimer(withTimeInterval: Self.timerInterval, repeats: true) { _ in
            self.tick()
        }
    }
    
    func stopTicking() { 
        // TODO
    }
    
    // TODO: Implement Audio buffering and synchronisation.
    func tick() {
        timerQueue.async {
            
            while self.cycles < Self.machineCyclesCyclesPerFrame {
                if !APU.shared.isDrainingSamples {
                    let cpuCycles = CPU.shared.tick()
                    self.incrementDivCounter(cycles: cpuCycles)
                    self.incrementTimaRegister(cycles: cpuCycles)
                    
                    // If cycles accumulated during CPU tick is 0, then that means that the HALT flag is set.
                    // In this case, we still want the PPU to tick one cycle as only the CPU instructions and timers are paused when the HALT flag is set.
                    let adjustedCycles = max(cpuCycles, 1)
                    PPU.shared.tick(cycles: adjustedCycles)
                    APU.shared.tick(clockCycles: adjustedCycles)
                    
                    self.cycles += adjustedCycles
                }
            }
            
            self.cycles -= Int(Self.machineCyclesCyclesPerFrame) // Keep overflowed values instead of just resetting to zero
            self.screenRenderDelegate?.renderScreen(screenData: PPU.shared.screenData)
        }
    }
    
    // TODO: Pull out the registers from the MMU into this class.
    // This thing is pretty complicated: https://gbdev.gg8.se/wiki/articles/Timer_Obscure_Behaviour
    // TODO: The rest of the complexity.
    private func incrementTimaRegister(cycles: Int) {
        let tac = MMU.shared.unsafeReadValue(globalAddress: Memory.addressTAC)
        let isClockEnabled = tac.checkBit(Memory.timaEnabledBitIndex)
        guard isClockEnabled else { return }
        
        timaTimer += cycles
        if timaTimer >= clockCyclesPerTimaCycle {
            timaTimer -= Int(clockCyclesPerTimaCycle) // Keep overflowed values instead of just resetting to zero
            
            let timaValue = MMU.shared.unsafeReadValue(globalAddress: Memory.addressTIMA)
            
            if timaValue == .max {
                // TODO: The following actually needs to be done after 1 cycle from this point.
                let tma = MMU.shared.unsafeReadValue(globalAddress: Memory.addressTMA)
                MMU.shared.unsafeWriteValue(tma, globalAddress: Memory.addressTIMA)
                MMU.shared.requestTimerInterrupt()
            } else {
                MMU.shared.unsafeWriteValue(timaValue &+ 1, globalAddress: Memory.addressTIMA)
            }
        }
    }
    
    func resetTimaCycle() {
        timaTimer = 0
    }
    
    // If the game changes this value via the writeMemory function, do we need to reset the timaTimer?
    var clockCyclesPerTimaCycle: UInt32 {
        let rawValue = MMU.shared.unsafeReadValue(globalAddress: Memory.addressTAC) & 0b11
        switch rawValue {
        case 0b00: return 1024 // 4096 Hz
        case 0b01: return 16 // 262144 Hz
        case 0b10: return 64 // 65536 Hz
        case 0b11: return 256 // 16384 Hz
        default: fatalError("This should never be reached.")
        }
    }
}

// MARK: - DIV

extension MasterClock {
    
    private func incrementDivCounter(cycles: Int) {
        let (newInternalDivCounter, overflow) = internalDivCounter.addingReportingOverflow(UInt8(cycles))
        internalDivCounter = newInternalDivCounter
        if overflow {
            setDivRegister(newValue: divRegister &+ 1)
        }
    }
    
    func readDIV() -> UInt8 {
        divRegister
    }
    
    func clearDIV() {
        internalDivCounter = 0
        setDivRegister(newValue: 0)
    }
    
    private func setDivRegister(newValue: UInt8) {
        let oldDiv = divRegister
        divRegister = newValue
        
        let bit4Overflow = oldDiv.checkBit(4) && !divRegister.checkBit(4)
        if bit4Overflow {
            APU.shared.tickFrameSquencer()
        }
    }
}

// TODO: Cleanup and rename
protocol ScreenRenderDelegate: AnyObject {
    func renderScreen(screenData: [ColourPalette.PixelData])
}
