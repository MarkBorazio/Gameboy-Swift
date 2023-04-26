//
//  InaccurateSoundChannel2.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 24/4/2023.
//

import Foundation
import AVFAudio

// Square Wave
// Same as Channel 1, but has no wavelength sweep
class InaccurateSoundChannel2 {
    
    private let signal = Oscillator.square
    
    private var isEnabled = false
    private var isDACEnabled = false // TODO: Fade out when set to false

    private var nr21: UInt8 = 0
    private var nr22: UInt8 = 0
    private var nr23: UInt8 = 0
    private var nr24: UInt8 = 0 {
        didSet {
            triggerChannelIfRequired()
        }
    }
    
    private var dutyCycleBitPointer: Int = 0
    private var lengthTimer: UInt8 = 0

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

extension InaccurateSoundChannel2 {
    
    func read(address: UInt16) -> UInt8 {
        print("TODO: SoundChannel1.read(address: \(address))")
        return 0
    }
    
    func write(_ value: UInt8, address: UInt16) {
        switch address {
        case Memory.addressNR21: nr21 = value
        case Memory.addressNR22: nr22 = value
        case Memory.addressNR23: nr23 = value
        case Memory.addressNR24: nr24 = value
        default: fatalError("Unknown SoundChannel2 address received. Got \(address.hexString()).")
        }
    }
}

// MARK: - NR21: Length and Duty Cycle

extension InaccurateSoundChannel2 {
    
    private static let maxTimerLength: UInt8 = 64
    
    private static let dutyCycles: [Double] = [
        0.125,
        0.25,
        0.50,
        0.75
    ]
    
    var initialLengthTimerValue: UInt8 {
        nr21 & 0b0011_1111
    }
    
    var dutyCyclePatternPointer: UInt8 {
        (nr21 & 0b1100_0000) >> 6
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

// MARK: - NR22: Amplitude Sweep

extension InaccurateSoundChannel2 {
    
    private static let amplitudeRawRange = 0x0...0xF
    
    private func triggerAmplitudeSweep() {
        amplitudeSweepPace = nr22 & 0b111
        amplitudeSweepAddition = nr22.checkBit(3)
        amplitudeRaw = (nr22 & 0b1111_0000) >> 4
        isDACEnabled = (nr22 & 0b1111_1000) != 0
        
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

// MARK: - NR23: Wavelength Low | NR24: Wavelength High and Control

extension InaccurateSoundChannel2 {
    
    private var wavelength: UInt16 {
        let highByte = (UInt16(nr24) & 0b111) << 8
        let lowByte = UInt16(nr23)
        return highByte | lowByte
    }
    
    private var lengthTimerEnabled: Bool {
        nr24.checkBit(6)
    }
    
    // Ref: https://gbdev.gg8.se/wiki/articles/Gameboy_sound_hardware
    private func triggerChannelIfRequired() {
        let shouldTrigger = nr24.checkBit(7)
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
        
        amplitudeSweepPace = nr22 & 0b111
        amplitudeSweepAddition = nr22.checkBit(3)
        amplitudeRaw = (nr22 & 0b1111_0000) >> 4
        isDACEnabled = (nr22 & 0b1111_1000) != 0
        
        // Disabling DAC disables channel
        // Enabling DAC does not enable channel
        if !isDACEnabled {
            isEnabled = false
        }
    }
}
