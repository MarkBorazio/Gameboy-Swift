//
//  MasterClock.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 26/3/2023.
//

import Foundation
import Cocoa

class MasterClock {
    
    private var isTicking = false
    private let timerQueue = DispatchQueue(label: "timerQueue")
    
    private static let tCyclesHz: Double = 4194304
    private static let framesPerSecond: UInt32 = 60
    
    var multipliedTCyclesHz: UInt32 { UInt32(Self.tCyclesHz * GameBoy.instance.settings.clockMultiplier) }
    private var tCyclesCyclesPerFrame: UInt32 { multipliedTCyclesHz / Self.framesPerSecond }
    private var frameDuration: TimeInterval { 1.0 / Double(Self.framesPerSecond) }
    
    private var internalDivCounter: UInt8 = 0
    private(set) var divRegister: UInt8 = 0
    
    private var internalTimaCounter: Int = 0
    var timaRegister: UInt8 = 0
    var tmaRegister: UInt8 = 0
    private(set) var tacRegister: UInt8 = 0
    
    // Game speed is synced by audio.
    func startTicking() {
        isTicking = true
        timerQueue.async {
            var nextRenderDate = Date().addingTimeInterval(self.frameDuration)
            while(self.isTicking) {
                if !GameBoy.instance.apu.isDrainingSamples {
                    let cpuMCycles = GameBoy.instance.cpu.tickReturningMCycles()
                    // If cycles accumulated during CPU tick is 0, then that means that the HALT flag is set.
                    // In this case, we still want to tick everything else over.
                    let adjustedMCycles = max(cpuMCycles, 1)
                    let tCycles = adjustedMCycles * 4
                    
                    self.incrementDivCounter(tCycles: tCycles)
                    self.incrementTimaRegister(tCycles: tCycles)
                    GameBoy.instance.ppu.tick(tCycles: tCycles)
                    GameBoy.instance.apu.tick(tCycles: tCycles)
                }
                
                let now = Date()
                if now >= nextRenderDate {
                    nextRenderDate = now.addingTimeInterval(self.frameDuration)
                    GameBoy.instance.requestScreenRender()
                }
            }
        }
    }
    
    func stopTicking() {
        isTicking = false
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
            GameBoy.instance.apu.tickFrameSquencer()
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
        default: Coordinator.instance.crash(message: "This should never be reached.")
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
                GameBoy.instance.mmu.requestTimerInterrupt()
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
