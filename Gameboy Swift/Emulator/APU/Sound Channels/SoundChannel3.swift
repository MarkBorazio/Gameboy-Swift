//
//  SoundChannel3.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 30/4/2023.
//

import Foundation

// Custom Wave Channel
class SoundChannel3 {
    
    private static let lengthTime: UInt8 = 64
    
    var isEnabled = false
    
    private var nr30: UInt8 = 0 {
        didSet {
            disableChannelIfRequired()
        }
    }
    private var nr31: UInt8 = 0
    private var nr32: UInt8 = 0
    private var nr33: UInt8 = 0
    private var nr34: UInt8 = 0 {
        didSet {
            triggerChannelIfRequired()
        }
    }
    private var sampleBuffer: [UInt8] = Array(repeating: 0, count: 32) // Wave Pattern RAM
    private var samplePointer: Int = 1 // Starts at 1, apparently
    
    private var frequencyTimer: Int = calculateInitialFrequencyTimer(wavelength: 0)
    private var lengthTimer: UInt8 = 0
    
    private static func calculateInitialFrequencyTimer(wavelength: UInt16) -> Int {
         (2048 - Int(wavelength)) * 4
    }
    
    func dacOutput() -> Float {
        guard isDACEnabled else { return 0.0 }
        guard isEnabled else { return 1.0 }
        
        let rawSample = sampleBuffer[samplePointer] & 0xF
        let dacInput = rawSample >> amplitudeShiftAmount
        
        // Normalise input of 0x0...0xF to output of 1.0...-1.0
        let dacOutput = (-Float(dacInput) / 7.5) + 1.0
        
        return dacOutput
    }
    
    func tickLengthTimer() {
        guard lengthTimerEnabled else { return }
        if lengthTimer > 0 {
            lengthTimer -= 1
        }
        if lengthTimer == 0 {
            lengthTimer = Self.lengthTime - initialLengthTimerValue
            isEnabled = false
        }
    }
    
    func tickFrequencyTimer(tCycles: Int) {
        frequencyTimer -= tCycles
        if frequencyTimer <= 0 {
            frequencyTimer += Self.calculateInitialFrequencyTimer(wavelength: wavelength)
            samplePointer = (samplePointer + 1) & 31 // Equivalent to `(samplePointer + 1) % 32`
        }
    }
}

// MARK: - Read And Write

extension SoundChannel3 {
    
    func read(address: UInt16) -> UInt8 {
        switch address {
        case Memory.addressNR30: return nr30
        case Memory.addressNR31: return 0 // Write only
        case Memory.addressNR32: return nr32
        case Memory.addressNR33: return 0 // Write only
        case Memory.addressNR34: return nr34 & 0b0100_0000
        case Memory.addressChannel3WavePatternsRange: return readWaveRAM(globalAddress: address)
        default: Coordinator.instance.crash(message: "Unknown SoundChannel3 read address received. Got \(address.hexString()).")
        }
    }
    
    func write(_ value: UInt8, address: UInt16) {
        switch address {
        case Memory.addressNR30: nr30 = value
        case Memory.addressNR31: nr31 = value
        case Memory.addressNR32: nr32 = value
        case Memory.addressNR33: nr33 = value
        case Memory.addressNR34: nr34 = value
        case Memory.addressChannel3WavePatternsRange: writeWaveRAM(value, globalAddress: address)
        default: Coordinator.instance.crash(message: "Unknown SoundChannel3 write address received. Got \(address.hexString()).")
        }
    }
    
    private func readWaveRAM(globalAddress: UInt16) -> UInt8 {
        let sampleIndex = globalAddress - Memory.addressChannel3WavePatternsRange.lowerBound
        let highNibble = sampleBuffer[sampleIndex] & 0xF
        let lowNibble = sampleBuffer[sampleIndex+1] & 0xF
        return highNibble << 4 | lowNibble
    }
    
    private func writeWaveRAM(_ value: UInt8, globalAddress: UInt16) {
        let sampleIndex = globalAddress - Memory.addressChannel3WavePatternsRange.lowerBound
        sampleBuffer[sampleIndex] = value.highNibble
        sampleBuffer[sampleIndex+1] = value.lowNibble
    }
}

// MARK: - NR30: DAC Enable

extension SoundChannel3 {
    
    private var isDACEnabled: Bool {
        nr30.checkBit(7)
    }
    
    private func disableChannelIfRequired() {
        if !isDACEnabled {
            isEnabled = false
        }
    }
}

// MARK: - NR31: Length Timer

extension SoundChannel3 {
    
    private var initialLengthTimerValue: UInt8 {
        nr31
    }
}

// MARK: - NR32: Amplitude Shift (Volume Control)

extension SoundChannel3 {
    
    private var amplitudeShiftAmount: UInt8 {
        let rawValue = (nr32 & 0b0110_0000) >> 5
        switch rawValue {
        case 0b00: return 4 // Mute
        case 0b01: return 0 // 100%
        case 0b10: return 1 // 50%
        case 0b11: return 2 // 25%
        default: Coordinator.instance.crash(message: "Unrecognised amplitude shift amount. Got \(rawValue).")
        }
    }
}

// MARK: - NR33: Wavelength Low | NR34: Wavelength High and Control

extension SoundChannel3 {
    
    private var wavelength: UInt16 {
        get {
            let highByte = (UInt16(nr34) & 0b111) << 8
            let lowByte = UInt16(nr33)
            return highByte | lowByte
        }
        set {
            let highByte = newValue.getByte(1) & 0b111
            let lowByte = newValue.getByte(0)
            nr34 |= highByte
            nr33 = lowByte
        }
    }
    
    private var lengthTimerEnabled: Bool {
        nr34.checkBit(6)
    }
    
    // Ref: https://gbdev.gg8.se/wiki/articles/Gameboy_sound_hardware
    private func triggerChannelIfRequired() {
        let shouldTrigger = nr34.checkBit(7)
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
        samplePointer = 0
        
        // Disabling DAC disables channel
        // Enabling DAC does not enable channel
        if !isDACEnabled {
            isEnabled = false
        }
    }
}
