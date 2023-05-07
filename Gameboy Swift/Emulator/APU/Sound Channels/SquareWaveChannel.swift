//
//  SoundChannel2.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 24/4/2023.
//

import Foundation
import AVFAudio

// Used for common behaviour between Channel 1 and Channel 2
class SquareWaveChannel {
    
    var nrX0: UInt8 = 0
    var nrX1: UInt8 = 0 {
        didSet {
            reloadLengthTimer()
        }
    }
    var nrX2: UInt8 = 0 {
        didSet {
            disableChannelIfRequired()
        }
    }
    var nrX3: UInt8 = 0
    var nrX4: UInt8 = 0 {
        didSet {
            triggerChannelIfRequired()
        }
    }

    var isEnabled = false
    
    private var frequencyTimer: Int = calculateInitialFrequencyTimer(wavelength: 0)
    private var dutyCycleBitPointer: Int = 0
    private var lengthTimer: UInt8 = 0
    
    private var wavelengthSweepCounter = 0

    private var amplitudeRaw: UInt8 = 0
    private var amplitudeSweepAddition = false
    private var amplitudeSweepPace: UInt8 = 0
    private var amplitudeSweepCounter = 0
    
    private static func calculateInitialFrequencyTimer(wavelength: UInt16) -> Int {
         (2048 - Int(wavelength)) * 4
    }
    
    func tickFrequencyTimer(tCycles: Int) {
        frequencyTimer -= tCycles
        if frequencyTimer <= 0 {
            frequencyTimer += Self.calculateInitialFrequencyTimer(wavelength: wavelength)
            dutyCycleBitPointer = (dutyCycleBitPointer + 1) & 0b111
        }
    }
    
    func dacOutput() -> Float {
        guard isDACEnabled else { return 0.0 }
        guard isEnabled else { return 1.0 }
        
        let dutyCycleValue = Self.dutyCyclePatterns[dutyCyclePatternPointer].getBitValue(dutyCycleBitPointer)
        let dacInput = dutyCycleValue * amplitudeRaw
        
        // Normalise input of 0x0...0xF to output of 1.0...-1.0
        let dacOutput = (-Float(dacInput) / 7.5) + 1.0
        
        return dacOutput
    }
    
    func tickWavelengthSweepCounter() {
        wavelengthSweepCounter += 1
        if wavelengthSweepCounter == wavelengthSweepPace {
            wavelengthSweepCounter = 0
            iterateWavelengthSweep()
        }
    }
}

// MARK: - NRX0 Wavelength Sweep

extension SquareWaveChannel {
    
    private var wavelengthSweepSlope: UInt8 {
        nrX0 & 0b111
    }
    
    private var wavelengthSweepAddition: Bool {
        nrX0.checkBit(3)
    }
    
    private var wavelengthSweepPace: UInt8 {
        (nrX0 & 0b0111_0000) >> 4
    }

    private func iterateWavelengthSweep() {
        let arithmeticFuction: ((UInt16, UInt16) -> UInt16) = wavelengthSweepAddition ? (+) : (-)
        let divisor = pow(2.0, Float(wavelengthSweepSlope))
        let difference = wavelength / UInt16(divisor)
        let newWavelength = arithmeticFuction(wavelength, difference)

        let didOverflow = newWavelength.checkBit(11)
        if didOverflow && wavelengthSweepAddition {
            isEnabled = false
        }

        if isEnabled {
            let sweepIterationsEnabled = wavelengthSweepSlope != 0
            if sweepIterationsEnabled {
                wavelength = newWavelength & 0b111_1111_1111 // 11 bits wide
            }
        }

        // TODO: Should this run again as per https://gbdev.gg8.se/wiki/articles/Gameboy_sound_hardware ?
    }
}

// MARK: - NRX1: Length and Duty Cycle

extension SquareWaveChannel {
    
    private static let maxLengthTime: UInt8 = 64
    
    // `dutyCyclePatternPointer` is used to retrieve the duty cycle from this array
    private static let dutyCyclePatterns: [UInt8] = [
        0b00000001, // 12.5%
        0b00000011, // 25%
        0b00001111, // 50%
        0b11111100 // 75%
    ]
    
    var initialLengthTimerValue: UInt8 {
        nrX1 & 0b0011_1111
    }
    
    var dutyCyclePatternPointer: UInt8 {
        (nrX1 & 0b1100_0000) >> 6
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

// MARK: - NRX2: Amplitude Sweep and DAC Enable

extension SquareWaveChannel {
    
    private static let amplitudeRawRange = 0x0...0xF
    
    private var isDACEnabled: Bool { // TODO: Fade out when set to false
        (nrX2 & 0b1111_1000) != 0
    }
    
    private func triggerAmplitudeSweep() {
        amplitudeSweepPace = nrX2 & 0b111
        amplitudeSweepAddition = nrX2.checkBit(3)
        amplitudeRaw = (nrX2 & 0b1111_0000) >> 4
        
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

// MARK: - NRX3: Wavelength Low | NRX4: Wavelength High and Control

extension SquareWaveChannel {
    
    private var wavelength: UInt16 {
        get {
            let highByte = (UInt16(nrX4) & 0b111) << 8
            let lowByte = UInt16(nrX3)
            return highByte | lowByte
        }
        set {
            let highByte = newValue.getByte(1) & 0b111
            let lowByte = newValue.getByte(0)
            nrX4 |= highByte
            nrX3 = lowByte
        }
    }
    
    private var lengthTimerEnabled: Bool {
        nrX4.checkBit(6)
    }
    
    // Ref: https://gbdev.gg8.se/wiki/articles/Gameboy_sound_hardware
    private func triggerChannelIfRequired() {
        let shouldTrigger = nrX4.checkBit(7)
        guard shouldTrigger else { return }
        triggerChannel()
    }
    
    private func triggerChannel() {
        isEnabled = isDACEnabled
        
        if lengthTimer == 0 {
            lengthTimer = Self.maxLengthTime
        }
        frequencyTimer = Self.calculateInitialFrequencyTimer(wavelength: wavelength)
        triggerAmplitudeSweep()
    }
}
