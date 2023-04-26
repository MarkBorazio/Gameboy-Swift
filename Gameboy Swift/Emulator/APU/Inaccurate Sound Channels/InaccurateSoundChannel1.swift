//
//  InaccurateSoundChannel1.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 23/4/2023.
//

import Foundation
import AVFAudio

// Square Wave
// Same as Channel 2, but this has a wavelength sweep
class InaccurateSoundChannel1 {
    
    private let signal = Oscillator.square
    
    private var isEnabled = false
    private var isDACEnabled = false // TODO: Fade out when set to false

    private var nr10: UInt8 = 0
    private var nr11: UInt8 = 0
    private var nr12: UInt8 = 0
    private var nr13: UInt8 = 0
    private var nr14: UInt8 = 0 {
        didSet {
            triggerChannelIfRequired()
        }
    }
    
    private var dutyCycleBitPointer: Int = 0
    private var lengthTimer: UInt8 = 0
    
    private var wavelengthSweepCounter = 0

    private var amplitudeRaw: UInt8 = 0
    private var amplitudeSweepAddition = false
    private var amplitudeSweepPace: UInt8 = 0
    private var amplitudeSweepCounter = 0
    
    private var time: Float = 0
    private var frequency: Float {
        Float(131072) / Float(2048 - wavelength)
    }
    
    private let sampleLengthSeconds: Float
    
    init(sampleLengthSeconds: Float) {
        self.sampleLengthSeconds = sampleLengthSeconds
    }
    
    lazy var sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList in
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        
        let localFrequency = self.frequency
        let period = 1 / localFrequency
        let dutyCycle = Self.dutyCycles[self.dutyCyclePatternPointer]
        let amplitude = (Float(self.amplitudeRaw) / 7.5) - 1.0
        
        for frame in 0..<Int(frameCount) {
            let percentComplete = self.time / period
            
            let sampleValue: Float
            if self.isDACEnabled && self.isEnabled {
                sampleValue = self.signal(localFrequency * percentComplete, self.time, dutyCycle, amplitude)
            } else {
                sampleValue = 0.0
            }
            
            self.time += self.sampleLengthSeconds
            self.time = fmod(self.time, period)
            
            for buffer in ablPointer {
                let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                buf[frame] = sampleValue
            }
        }
        
        return noErr
    }
}

// MARK: - Read/Write

extension InaccurateSoundChannel1 {
    
    func read(address: UInt16) -> UInt8 {
        print("TODO: SoundChannel1.read(address: \(address))")
        return 0
    }
    
    func write(_ value: UInt8, address: UInt16) {
        switch address {
        case Memory.addressNR10: nr10 = value
        case Memory.addressNR11: nr11 = value
        case Memory.addressNR12: nr12 = value
        case Memory.addressNR13: nr13 = value
        case Memory.addressNR14: nr14 = value
        default: fatalError("Unknown SoundChannel2 address received. Got \(address.hexString()).")
        }
    }
}

// MARK: - NR10 Wavelength Sweep

extension InaccurateSoundChannel1 {
    
    private var wavelengthSweepSlope: UInt8 {
        nr10 & 0b111
    }
    
    private var wavelengthSweepAddition: Bool {
        nr10.checkBit(3)
    }
    
    private var wavelengthSweepPace: UInt8 {
        (nr10 & 0b0111_0000) >> 4
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

    func tickWavelengthSweepCounter() {
        wavelengthSweepCounter += 1
        if wavelengthSweepCounter == wavelengthSweepPace {
            wavelengthSweepCounter = 0
            iterateWavelengthSweep()
        }
    }
}

// MARK: - NR11: Length and Duty Cycle

extension InaccurateSoundChannel1 {
    
    private static let maxTimerLength: UInt8 = 64
    
    private static let dutyCycles: [Double] = [
        0.125,
        0.25,
        0.50,
        0.75
    ]
    
    var initialLengthTimerValue: UInt8 {
        nr11 & 0b0011_1111
    }
    
    var dutyCyclePatternPointer: UInt8 {
        (nr11 & 0b1100_0000) >> 6
    }
    
    func tickLengthTimer() {
        guard lengthTimerEnabled else { return }
        lengthTimer -= 1
        if lengthTimer == 0 {
            lengthTimer = Self.maxTimerLength - initialLengthTimerValue
            isEnabled = false
        }
    }
}

// MARK: - NR12: Amplitude Sweep

extension InaccurateSoundChannel1 {
    
    private static let amplitudeRawRange = 0x0...0xF
    
    private func triggerAmplitudeSweep() {
        amplitudeSweepPace = nr12 & 0b111
        amplitudeSweepAddition = nr12.checkBit(3)
        amplitudeRaw = (nr12 & 0b1111_0000) >> 4
        isDACEnabled = (nr12 & 0b1111_1000) != 0
        
        // Disabling DAC disables channel
        // Enabling DAC does not enable channel
        if !isDACEnabled {
            isEnabled = false
        }
    }
    
    private func iterateAmplitudeSweep() {
        let arithmeticFuction: ((Int, Int) -> Int) = amplitudeSweepAddition ? (+) : (-)
        let newAmplitudeRaw = arithmeticFuction(Int(amplitudeRaw), 1)
        
        if Self.amplitudeRawRange.contains(newAmplitudeRaw) {
            amplitudeRaw = UInt8(newAmplitudeRaw)
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

// MARK: - NR13: Wavelength Low | NR14: Wavelength High and Control

extension InaccurateSoundChannel1 {
    
    private var wavelength: UInt16 {
        get {
            let highByte = (UInt16(nr14) & 0b111) << 8
            let lowByte = UInt16(nr13)
            return highByte | lowByte
        }
        set {
            let highByte = newValue.getByte(1) & 0b111
            let lowByte = newValue.getByte(0)
            nr14 |= highByte
            nr13 = lowByte
        }
    }
    
    private var lengthTimerEnabled: Bool {
        nr14.checkBit(6)
    }
    
    // Ref: https://gbdev.gg8.se/wiki/articles/Gameboy_sound_hardware
    private func triggerChannelIfRequired() {
        let shouldTrigger = nr14.checkBit(7)
        guard shouldTrigger else { return }
        
        let dacWasOff = !isDACEnabled
        
        triggerChannel()
        
        // Note that if the channel's DAC is off, after the above actions occur the channel will be immediately disabled again.
        if dacWasOff {
            isEnabled = false
        }
    }
    
    private func triggerChannel() {
        isEnabled = true
        
        if lengthTimer == 0 {
            lengthTimer = Self.maxTimerLength
        }
        
        amplitudeSweepPace = nr12 & 0b111
        amplitudeSweepAddition = nr12.checkBit(3)
        amplitudeRaw = (nr12 & 0b1111_0000) >> 4
        isDACEnabled = (nr12 & 0b1111_1000) != 0
        
        // Disabling DAC disables channel
        // Enabling DAC does not enable channel
        if !isDACEnabled {
            isEnabled = false
        }
    }
}

