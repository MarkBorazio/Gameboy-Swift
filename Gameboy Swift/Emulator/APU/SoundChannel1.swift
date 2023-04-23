//
//  SoundChannel1.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 23/4/2023.
//

import Foundation
import AVFAudio

// Square Wave
class SoundChannel1 {
    
    let signal = Oscillator.square
    
    private let deltaTime: Float // Sample length, in seconds
    private var time: Float = 0
    private var isOn = false {
        didSet {
            if !isOn {
                dutyCycle = 0.5
                initialLengthTimerValue = 0
                lengthTimer = 0
                lengthTimerEnabled = false
                wavelength = 0
                wavelengthSweepSlope = 0
                wavelengthSweepPace = 0
                wavelengthSweepAddition = false
                wavelengthSweepCounter = 0
                amplitudeRaw = 0
                amplitudeSweepAddition = false
                amplitudeSweepPace = 0
                amplitudeSweepCounter = 0
            }
        }
    }
    
    private var dutyCycle: Double = 0.5
    private var initialLengthTimerValue: UInt8 = 0
    private var lengthTimer: UInt8 = 0
    private var lengthTimerEnabled = false
    
    private var wavelength: UInt16 = 0
    private var wavelengthSweepSlope: UInt8 = 0
    private var wavelengthSweepPace: UInt8 = 0
    private var wavelengthSweepAddition = false
    private var wavelengthSweepCounter = 0
    
    private var amplitudeRaw: UInt8 = 0
    private var amplitudeSweepAddition = false
    private var amplitudeSweepPace: UInt8 = 0
    private var amplitudeSweepCounter = 0
    
    private var frequency: Float {
        Float(131072) / Float(2048 - wavelength)
    }
    
    private var amplitudeNormalised: Float {
        Float(amplitudeRaw) / Float(0xF)
    }
    
    init(deltaTime: Float) {
        self.deltaTime = deltaTime
    }
    
    lazy var sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList in
        guard self.isOn else { return noErr }
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
  
        let localFrequency = self.frequency
        let period = 1 / localFrequency

        for frame in 0..<Int(frameCount) {
            let percentComplete = self.time / period
            let sampleVal = self.signal(localFrequency * percentComplete, self.time, self.dutyCycle, self.amplitudeNormalised)
            self.time += self.deltaTime
            self.time = fmod(self.time, period)
            
            for buffer in ablPointer {
                let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                buf[frame] = sampleVal
            }
        }
        
        return noErr
    }
}

// MARK: - Read/Write

extension SoundChannel1 {
    
    func read(address: UInt16) -> UInt8 {
        print("TODO: SoundChannel1.read(address: \(address))")
        return 0
    }
    
    func write(_ value: UInt8, address: UInt16) {
        switch address {
        case Memory.addressSoundChannel1WavelengthSweep: updateWavelengthSweep(value: value)
        case Memory.addressSoundChannel1LengthAndDutyCycle: updateLengthAndDutyCycle(value: value)
        case Memory.addressSoundChannel1AmplitudeSweep: updateAmplitudeSweep(value: value)
        case Memory.addressSoundChannel1WavelengthLow: updateWavelengthLow(value: value)
        case Memory.addressSoundChannel1WavelengthHighAndControl: updateWavelengthHighAndControl(value: value)
        default: fatalError("Unknown SoundChannel1 address received. Got \(address.hexString()).")
        }
    }
}

// MARK: - Wavelength Sweep

extension SoundChannel1 {
    
    private func updateWavelengthSweep(value: UInt8) {
        wavelengthSweepSlope = value & 0b111
        wavelengthSweepAddition = value.checkBit(3)
        wavelengthSweepPace = (value & 0b0111_0000) >> 4
    }
    
    private func iterateWavelengthSweep() {
        let arithmeticFuction: ((UInt16, UInt16) -> UInt16) = wavelengthSweepAddition ? (+) : (-)
        let divisor = pow(2.0, Float(wavelengthSweepSlope))
        let difference = wavelength / UInt16(divisor)
        let newWavelength = arithmeticFuction(wavelength, difference)
        
        let didOverflow = newWavelength.checkBit(11)
        if didOverflow && wavelengthSweepAddition {
            isOn = false
        }
        
        // TODO: Check if we should update the wavelength if we overflowed
        let sweepIterationsEnabled = wavelengthSweepSlope != 0
        if sweepIterationsEnabled {
            wavelength = newWavelength & 0b111_1111_1111 // 11 bits wide
        }
    }
    
    func tickWavelengthSweepCounter() {
        wavelengthSweepCounter += 1
        if wavelengthSweepCounter == wavelengthSweepPace {
            wavelengthSweepCounter = 0
            iterateWavelengthSweep()
        }
    }
}

// MARK: - Length and Duty Cycle

extension SoundChannel1 {
    
    private static let dutyCycleOneEighth: UInt8 = 0b00 // 12.5%
    private static let dutyCycleOneQuarter: UInt8 = 0b01 // 25%
    private static let dutyCycleOneHalf: UInt8 = 0b10 // 50%
    private static let dutyCycleThreeQuarters: UInt8 = 0b01 // 75%
    
    private func updateLengthAndDutyCycle(value: UInt8) {
        initialLengthTimerValue = value & 0b0011_1111
        
        let dutyCycleRaw = (value & 0b1100_0000) >> 6
        switch dutyCycleRaw {
        case Self.dutyCycleOneEighth: dutyCycle = 0.125
        case Self.dutyCycleOneQuarter: dutyCycle = 0.25
        case Self.dutyCycleOneHalf: dutyCycle = 0.50
        case Self.dutyCycleThreeQuarters: dutyCycle = 0.75
        default: fatalError("Unknown raw duty cycled received. Got \(dutyCycleRaw.hexString()).")
        }
    }
    
    func tickLengthTimer() {
        lengthTimer += 1
        if lengthTimer == 64 {
            lengthTimer = initialLengthTimerValue
            isOn = false
        }
    }
}

// MARK: - Amplitude Sweep

extension SoundChannel1 {
    
    // TODO: Writes to this register while the channel is on require retriggering to activate
    private func updateAmplitudeSweep(value: UInt8) {
        amplitudeSweepPace = value & 0b111
        amplitudeSweepAddition = value.checkBit(3)
        amplitudeRaw = (value & 0b1111_0000) >> 4
        
        let shouldTurnOff = (value & 0b1111_1000) == 0
        if shouldTurnOff {
            isOn = false
        }
    }
    
    private func iterateAmplitudeSweep() {
        guard amplitudeSweepPace != 0 else { return }
        let arithmeticFuction: ((Int, Int) -> Int) = amplitudeSweepAddition ? (+) : (-)
        let newAmplitudeRaw = arithmeticFuction(Int(amplitudeRaw), 1)
        
        if newAmplitudeRaw < 0 {
            amplitudeRaw = 0
        } else if newAmplitudeRaw > 0xF {
            amplitudeRaw = 0xF
        } else {
            amplitudeRaw = UInt8(newAmplitudeRaw)
        }
    }
    
    func tickAmplitudeSweepCounter() {
        amplitudeSweepCounter += 1
        if amplitudeSweepCounter == amplitudeSweepPace {
            amplitudeSweepCounter = 0
            iterateAmplitudeSweep()
        }
    }
}

// MARK: - Wavelength and Control

extension SoundChannel1 {
    
    private func updateWavelengthLow(value: UInt8) {
        wavelength |= UInt16(value)
    }
    
    private func updateWavelengthHighAndControl(value: UInt8) {
        let wavelengthHighBits = value & 0b111
        let lengthTimerEnable = value.checkBit(6)
        let shouldTrigger = value.checkBit(7)
        
        self.lengthTimerEnabled = lengthTimerEnable
        wavelength |= UInt16(wavelengthHighBits) << 8
        
        // TODO: Handle this properly
        if shouldTrigger { // If DAC is off, this won't turn on
            isOn = true
        }
    }
}
