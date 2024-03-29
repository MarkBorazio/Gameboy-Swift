//
//  SoundChannel4.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 29/4/2023.
//

import Foundation

// Noise channel with amplitude envelope
class SoundChannel4 {
    
    private var nr40: UInt8 = 0
    private var nr41: UInt8 = 0 {
        didSet {
            reloadLengthTimer()
        }
    }
    private var nr42: UInt8 = 0 {
        didSet {
            disableChannelIfRequired()
        }
    }
    private var nr43: UInt8 = 0
    private var nr44: UInt8 = 0 {
        didSet {
            triggerChannelIfRequired()
        }
    }
    
    var isEnabled = false
    
    private var lsfr: UInt16 = 0 // Linear Feedback Shift Register
    
    private var lengthTimer: UInt8 = 0
    private var frequencyTimer: Int = 0
    
    private var amplitudeRaw: UInt8 = 0
    private var amplitudeSweepAddition = false
    private var amplitudeSweepPace: UInt8 = 0
    private var amplitudeSweepCounter = 0
    
    func dacOutput() -> Float {
        guard isDACEnabled else { return 0.0 }
        guard isEnabled else { return 1.0 }
        
        let lsfrValue = (~lsfr).getBitValue(0) // Get bit 0, inverted
        let dacInput = lsfrValue * UInt16(amplitudeRaw)
        
        // Normalise input of 0x0...0xF to output of 1.0...-1.0
        let dacOutput = (-Float(dacInput) / 7.5) + 1.0
        
        return dacOutput
    }
}

// MARK: - Read And Write

extension SoundChannel4 {
    
    func read(address: UInt16) -> UInt8 {
        switch address {
        case Memory.addressNR40: return 0xFF // Write only
        case Memory.addressNR41: return 0xFF // Write only
        case Memory.addressNR42: return nr42
        case Memory.addressNR43: return nr43
        case Memory.addressNR44: return nr44 | 0xBF
        default: Coordinator.instance.crash(message: "Unknown SoundChannel4 read address received. Got \(address.hexString()).")
        }
    }
    
    func write(_ value: UInt8, address: UInt16) {
        switch address {
        case Memory.addressNR40: nr40 = value
        case Memory.addressNR41: nr41 = value
        case Memory.addressNR42: nr42 = value
        case Memory.addressNR43: nr43 = value
        case Memory.addressNR44: nr44 = value
        default: Coordinator.instance.crash(message: "Unknown SoundChannel4 write address received. Got \(address.hexString()).")
        }
    }
    
}

// MARK: - NR41: Length

extension SoundChannel4 {
    
    private static let maxLengthTime: UInt8 = 64
    
    var initialLengthTimerValue: UInt8 {
        nr41 & 0b0011_1111
    }
    
    private func reloadLengthTimer() {
        lengthTimer = Self.maxLengthTime - initialLengthTimerValue
    }
    
    func tickLengthTimer() {
        guard lengthTimerEnabled else { return }
        if lengthTimer > 0 {
            lengthTimer -= 1
        }
        if lengthTimer == 0 {
            isEnabled = false
        }
    }
}

// MARK: - NR42: Amplitude Sweep and DAC Enable

extension SoundChannel4 {
    
    private static let amplitudeRawRange = 0x0...0xF
    
    private var isDACEnabled: Bool { // TODO: Fade out when set to false
        (nr42 & 0b1111_1000) != 0
    }
    
    private func triggerAmplitudeSweep() {
        amplitudeSweepPace = nr42 & 0b111
        amplitudeSweepAddition = nr42.checkBit(3)
        amplitudeRaw = (nr42 & 0b1111_0000) >> 4
        
        amplitudeSweepCounter = Int(amplitudeSweepPace) // Not sure if this should be done here
    }
    
    private func iterateAmplitudeSweep() {
        let arithmeticFuction: ((Int, Int) -> Int) = amplitudeSweepAddition ? (+) : (-)
        let newAmplitudeRaw = arithmeticFuction(Int(amplitudeRaw), 1)
        
        if Self.amplitudeRawRange.contains(newAmplitudeRaw) {
            amplitudeRaw = UInt8(newAmplitudeRaw)
        }
    }
    
    private func disableChannelIfRequired() {
        if !isDACEnabled {
            isEnabled = false
        }
    }
    
    func tickAmplitudeSweepCounter() {
        guard amplitudeSweepPace != 0 else { return }
        
        amplitudeSweepCounter -= 1
        if amplitudeSweepCounter <= 0 {
            amplitudeSweepCounter = Int(amplitudeSweepPace)
            iterateAmplitudeSweep()
        }
    }
}

// MARK: - NR43: LSFR

extension SoundChannel4 {
    
    private var clockShift: UInt8 {
        (nr43 & 0b1111_0000) >> 4
    }
    
    private var shortModeLSFR: Bool {
        nr43.checkBit(3)
    }
    
    private var clockDivisorCode: UInt8 {
        nr43 & 0b0000_0111
    }
    
    // Ref: https://nightshade256.github.io/2021/03/27/gb-sound-emulation.html
    private var clockDivisorValue: Int {
        if clockDivisorCode == 0 {
            return 8
        } else {
            return Int(clockDivisorCode << 4) // Equivalent to `Int(clockDivisorCode * 16)`
        }
    }
    
    private var frequencyLSFR: Int {
        clockDivisorValue << clockShift
    }
    
    private func iterateLSFR() {
        
        var mask: UInt16 = 0
        mask.setBit(15)
        if shortModeLSFR {
            mask.setBit(7)
        }
        
        let xorResult = lsfr.getBitValue(0) ^ lsfr.getBitValue(1)
        let shouldSet = xorResult == 1
        
        if shouldSet {
            lsfr |= mask // Set bit 15 (and bit 7 if short mode)
        } else {
            lsfr &= ~mask // Clear bit 15 (and bit 7 if short mode)
        }
        
        lsfr = lsfr >> 1
    }
    
    func tickFrequencyTimer(tCycles: Int) {
        frequencyTimer -= tCycles
        if frequencyTimer <= 0 {
            frequencyTimer += frequencyLSFR
            iterateLSFR()
        }
    }
}

// MARK: - NR44: Control

extension SoundChannel4 {
    
    private var lengthTimerEnabled: Bool {
        nr44.checkBit(6)
    }
    
    // Ref: https://gbdev.gg8.se/wiki/articles/Gameboy_sound_hardware
    private func triggerChannelIfRequired() {
        let shouldTrigger = nr44.checkBit(7)
        guard shouldTrigger else { return }
        triggerChannel()
    }
    
    private func triggerChannel() {
        isEnabled = isDACEnabled
        
        if lengthTimer == 0 {
            lengthTimer = Self.maxLengthTime
        }
        
        frequencyTimer = frequencyLSFR
        lsfr = .max // Not sure if all bits should be set to 1 or 0.
        
        triggerAmplitudeSweep()
    }
}
