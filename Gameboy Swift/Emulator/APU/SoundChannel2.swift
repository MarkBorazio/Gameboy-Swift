//
//  SoundChannel2.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 24/4/2023.
//

import Foundation
import AVFAudio

// Square Wave
// Same as Channel 1, but has no wavelength sweep
class SoundChannel2 {
    
    private static let lengthTime: UInt8 = 64
    
    private var nr21: UInt8 = 0
    private var nr22: UInt8 = 0
    private var nr23: UInt8 = 0
    private var nr24: UInt8 = 0 {
        didSet {
            triggerChannelIfRequired()
        }
    }
    
    private var isEnabled = false
    private var isDACEnabled = false // TODO: Fade out when set to false
    
    private var frequencyTimer: Int = calculateInitialFrequencyTimer(wavelength: 0)
    private var dutyCycleBitPointer: Int = 0
    private var lengthTimer: UInt8 = 0

    private var amplitudeRaw: UInt8 = 0
    private var amplitudeSweepAddition = false
    private var amplitudeSweepPace: UInt8 = 0
    private var amplitudeSweepCounter = 0
    
    lazy var sourceNode = AVAudioSourceNode { _, _, frameCount, audioBufferList in
        
        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

        for frame in 0..<Int(frameCount) {
            for buffer in ablPointer {
                let buf: UnsafeMutableBufferPointer<Float> = UnsafeMutableBufferPointer(buffer)
                buf[frame] = self.dacOutput()
            }
        }
        
        return noErr
    }
    
    func tickFrequencyTimer(clockCycles: Int) {
        frequencyTimer -= clockCycles
        if frequencyTimer <= 0 {
            frequencyTimer = Self.calculateInitialFrequencyTimer(wavelength: wavelength) - Int(frequencyTimer.magnitude)
            dutyCycleBitPointer = (dutyCycleBitPointer + 1) & 0b111
        }
    }
    
    private static func calculateInitialFrequencyTimer(wavelength: UInt16) -> Int {
         (2048 - Int(wavelength)) * 4
    }
    
    private func dacOutput() -> Float {
        guard isDACEnabled && isEnabled else { return 0.0 }
        
        let dutyCycleValue = Self.dutyCyclePatterns[dutyCyclePatternPointer].getBitValue(fakePointer)
        let dacInput = dutyCycleValue * amplitudeRaw
        
        // Normalise input of 0x0...0xF to output of -1.0...1.0
        let dacOutput = (Float(dacInput) / 7.5) - 1.0
        
        return dacOutput
    }
}

// MARK: - Read/Write

extension SoundChannel2 {
    
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

extension SoundChannel2 {
    
    // `dutyCyclePatternPointer` is used to retrieve the duty cycle from this array
    private static let dutyCyclePatterns: [UInt8] = [
        0b00000001, // 12.5%
        0b00000011, // 25%
        0b00001111, // 50%
        0b11111100 // 75%
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
            lengthTimer = Self.lengthTime - initialLengthTimerValue
            isEnabled = false
        }
    }
}

// MARK: - NR22: Amplitude Sweep

extension SoundChannel2 {
    
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

extension SoundChannel2 {
    
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
            lengthTimer = Self.lengthTime
        }
        frequencyTimer = Self.calculateInitialFrequencyTimer(wavelength: wavelength)
        
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
