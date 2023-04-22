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
    
    private static let clockCycleHz: UInt32 = 4194304
    private static let machineCyclesHz: UInt32 = clockCycleHz / 4
    private static let machineCyclesCyclesPerFrame: UInt32 = machineCyclesHz / framesPerSecond
    private static let timerInterval: TimeInterval = 1.0 / Double(framesPerSecond)
    
    private var cycles: Int = 0
    private var divTimer: UInt8 = 0
    private var timaTimer: Int = 0
    
    func startTicking() {
        self.timer = Timer.scheduledTimer(withTimeInterval: Self.timerInterval, repeats: true) { _ in
            self.tick()
        }
    }
    
    func stopTicking() { 
        // TODO
    }
    
    func tick() {
        timerQueue.async {
            while self.cycles < Self.machineCyclesCyclesPerFrame {
                let cpuCycles = CPU.shared.tick()
                self.incrementDivRegister(cycles: cpuCycles)
                self.incrementTimaRegister(cycles: cpuCycles)
                
                // If cycles accumulated during CPU tick is 0, then that means that the HALT flag is set.
                // In this case, we still want the PPU to tick one cycle as only the CPU instructions and timers are paused when the HALT flag is set.
                let adjustedCycles = max(cpuCycles, 1)
                PPU.shared.tick(cycles: adjustedCycles)
                
                self.cycles += adjustedCycles
            }
            
            self.cycles -= Int(Self.machineCyclesCyclesPerFrame) // Keep overflowed values instead of just resetting to zero
            self.screenRenderDelegate?.renderScreen(screenData: PPU.shared.screenData)
        }
    }
    
    private func incrementDivRegister(cycles: Int) {
        let (newDivTimer, overflow) = divTimer.addingReportingOverflow(UInt8(cycles))
        divTimer = newDivTimer
        if overflow {
            var div = MMU.shared.unsafeReadValue(globalAddress: Memory.addressDIV)
            div &+= 1
            MMU.shared.unsafeWriteValue(div, globalAddress: Memory.addressDIV)
        }
    }
    
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

// TODO: Cleanup and rename
protocol ScreenRenderDelegate: AnyObject {
    func renderScreen(screenData: [ColourPalette.PixelData])
}
