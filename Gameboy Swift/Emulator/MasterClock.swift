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
    private static let instructionClockCycleHz: UInt32 = clockCycleHz / 4
    private static let clockCyclesPerFrame: UInt32 = instructionClockCycleHz / framesPerSecond
    private static let timerInterval: TimeInterval = 1 / 60
    
    private var divTimer: Int = 0
    private var timaTimer = 0 // Increments at configurable frequency
    
    func startTicking() {
        let timerQueue = DispatchQueue(label: "timerQueue")
        timerQueue.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: Self.timerInterval, repeats: true, block: { _ in
                self.tick()
            })
            RunLoop.current.add(self.timer!, forMode: .common)
            RunLoop.current.run()
        }
    }
    
    func stopTicking() {
        // TODO
    }
    
    func tick() {
        var cycles = 0
        while cycles < Self.clockCyclesPerFrame {
//            print("cycles: \(cycles)")
            cycles += CPU.shared.executeInstruction()

            incrementDivRegister(cycles: cycles)
            incrementTimaRegister(cycles: cycles)
            PPU.shared.update(machineCycles: cycles)
            CPU.shared.handleInterrupts()
        }
        print("cycles! COMPLTETE")
        screenRenderDelegate?.renderScreen(screenData: PPU.shared.screenData)
    }
    
    private func incrementDivRegister(cycles: Int) {
        divTimer += cycles
        if divTimer >= 255 {
            divTimer = 0
            MMU.shared.memoryMap[MMU.addressDIV] &+= 1
        }
    }
    
    // This thing is pretty complicated: https://gbdev.gg8.se/wiki/articles/Timer_Obscure_Behaviour
    // TODO: The rest of the complexity.
    func incrementTimaRegister(cycles: Int) {
        let isClockEnabled = MMU.shared.memoryMap[MMU.addressTAC].checkBit(MMU.timaEnabledBitIndex)
        guard isClockEnabled else { return }
        
        timaTimer += cycles
        if timaTimer >= clockCyclesPerTimaCycle {
            timaTimer = 0
            
            let timaValue = MMU.shared.memoryMap[MMU.addressTIMA]
            
            if timaValue == .max {
                // TODO: The following actually needs to be done after 1 cycle from this point.
                MMU.shared.memoryMap[MMU.addressTIMA] = MMU.shared.memoryMap[MMU.addressTMA]
                MMU.shared.requestTimerInterrupt()
            } else {
                MMU.shared.memoryMap[MMU.addressTIMA] = timaValue &+ 1
            }
        }
    }
    
    
    // If the game changes this value via the writeMemory function, do we need to reset the timaTimer?
    private var clockCyclesPerTimaCycle: UInt32 {
        let rawValue = MMU.shared.memoryMap[MMU.addressTAC] & 0b11
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
