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
    private static let tCyclesCyclesPerFrame: UInt32 = tCyclesHz / framesPerSecond
    private static let timerInterval: TimeInterval = 1.0 / Double(framesPerSecond)
    
    private var tCyclesForCurrentFrame: Int = 0
    
    private var internalDivCounter: UInt8 = 0
    private(set) var divRegister: UInt8 = 0
    
    private var internalTimaCounter: Int = 0
    var timaRegister: UInt8 = 0
    var tmaRegister: UInt8 = 0
    private(set) var tacRegister: UInt8 = 0
    
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
            while self.tCyclesForCurrentFrame < Self.tCyclesHz {
                if !APU.shared.isDrainingSamples {
                    let cpuMCycles = CPU.shared.tickReturningMCycles()
                    let cpuTCycles = cpuMCycles * 4
                    
                    self.incrementDivCounter(tCycles: cpuTCycles)
                    self.incrementTimaRegister(tCycles: cpuTCycles)
                    
                    // If cycles accumulated during CPU tick is 0, then that means that the HALT flag is set.
                    // In this case, we still want the PPU to tick one cycle as only the CPU instructions and timers are paused when the HALT flag is set.
                    let adjustedTCycles = max(cpuTCycles, 4) // TODO: Figure out if min is 4 or 1.
                    PPU.shared.tick(tCycles: adjustedTCycles)
                    APU.shared.tick(tCycles: adjustedTCycles)
                    
                    self.tCyclesForCurrentFrame += adjustedTCycles
                }
            }
            
            self.tCyclesForCurrentFrame -= Int(Self.tCyclesCyclesPerFrame)
            self.screenRenderDelegate?.renderScreen(screenData: PPU.shared.screenData)
        }
    }
}

// MARK: - DIV

extension MasterClock {
    
    private func incrementDivCounter(tCycles: Int) {
        let (newInternalDivCounter, overflow) = internalDivCounter.addingReportingOverflow(UInt8(tCycles))
        internalDivCounter = newInternalDivCounter
        if overflow {
            setDivRegister(newValue: divRegister &+ 1)
        }
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

// MARK: - TIMA, TMA and TAC

extension MasterClock {
    
    private var isTimaClockEnabled: Bool {
        tacRegister.checkBit(2)
    }
    
    private var tCyclesPerTimaCycle: UInt32 {
        let rawValue = tacRegister & 0b11
        switch rawValue {
        case 0b00: return 1024 // 4096 Hz
        case 0b01: return 16 // 262144 Hz
        case 0b10: return 64 // 65536 Hz
        case 0b11: return 256 // 16384 Hz
        default: fatalError("This should never be reached.")
        }
    }
    
    // This thing is pretty complicated: https://gbdev.gg8.se/wiki/articles/Timer_Obscure_Behaviour
    // TODO: The rest of the complexity.
    private func incrementTimaRegister(tCycles: Int) {
        guard isTimaClockEnabled else { return }
        
        internalTimaCounter += tCycles
        if internalTimaCounter >= tCyclesPerTimaCycle {
            internalTimaCounter -= Int(tCyclesPerTimaCycle)
            
            if timaRegister == .max {
                // TODO: The following actually needs to be done after 1 cycle from this point.
                timaRegister = tmaRegister
                MMU.shared.requestTimerInterrupt()
            } else {
                timaRegister &+= 1
            }
        }
    }
    
    // If we change the clock frequency, we need to reset the counter.
    func writeTacRegister(_ value: UInt8) {
        let previousFrequency = tCyclesPerTimaCycle
        tacRegister = value
        let newFrequency = tCyclesPerTimaCycle
        if previousFrequency != newFrequency {
            internalTimaCounter = 0
        }
    }
}

// TODO: Cleanup and rename
protocol ScreenRenderDelegate: AnyObject {
    func renderScreen(screenData: [ColourPalette.PixelData])
}
