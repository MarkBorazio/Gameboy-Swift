//
//  APU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 23/4/2023.
//

import Foundation

class APU {
    
    static let shared = APU()
    
    private var isOn = false
    
    private var nr50: UInt8 = 0
    private var nr51: UInt8 = 0
    private var nr52: UInt8 {
        get { getNR52() }
        set { setNR52(newValue) }
    }
    
    private let synth = Synth()
    private let channel1 = SoundChannel1()
    private let channel2 = SoundChannel2()
    private let channel3 = SoundChannel3()
    private let channel4 = SoundChannel4()
    
    private let cyclesPerSample: Int
    
    private var interleavedSampleBuffer: [Float] = [] // L/R
    private var sampleCounter = 0
    private var isSampleBufferFull: Bool {
        interleavedSampleBuffer.count >= 1024 // 512 samples left and 512 samples right
    }
    
    private var divCounter = 0
    var isDrainingSamples = false
    
    init() {
        let cyclesPerSampleDouble = Double(MasterClock.mCyclesHz) / synth.sampleRate
        cyclesPerSample = Int(cyclesPerSampleDouble.rounded(.awayFromZero))
        
        synth.volume = 0.1
        synth.start()
    }
    
    func read(address: UInt16) -> UInt8 {
        switch address {
        case Memory.addressNR50:
            return nr50
            
        case Memory.addressNR51:
            return nr51
        
        case Memory.addressNR52:
            return nr52
            
        case Memory.addressChannel1Range:
            return channel1.read(address: address)
            
        case Memory.addressChannel2Range:
            return channel2.read(address: address)
            
        case Memory.addressChannel3Range, Memory.addressChannel3WavePatternsRange:
            return channel3.read(address: address)
            
        case Memory.addressChannel4Range:
            return channel4.read(address: address)
            
        default:
            fatalError("Unhandled APU read address received. Got: \(address.hexString()).")
        }
    }
    
    func write(_ value: UInt8, address: UInt16) {
        if address == Memory.addressNR52 {
            nr52 = value
        } else {
            guard isOn else { return }
            
            switch address {
            case Memory.addressNR50:
                nr50 = value
                
            case Memory.addressNR51:
                nr51 = value
                
            case Memory.addressChannel1Range:
                channel1.write(value, address: address)
                
            case Memory.addressChannel2Range:
                channel2.write(value, address: address)
                
            case Memory.addressChannel3Range, Memory.addressChannel3WavePatternsRange:
                channel3.write(value, address: address)
                
            case Memory.addressChannel4Range:
                channel4.write(value, address: address)
                
            default:
                fatalError("Unhandled APU write address received. Got: \(address.hexString()).")
            }
        }

    }
    
    func tick(clockCycles: Int) {
        guard isOn else { return }
        channel1.tickFrequencyTimer(clockCycles: clockCycles)
        channel2.tickFrequencyTimer(clockCycles: clockCycles)
        channel3.tickFrequencyTimer(clockCycles: clockCycles)
        channel4.tickFrequencyTimer(clockCycles: clockCycles)
        
        sampleCounter += clockCycles
        if sampleCounter >= cyclesPerSample {
            sampleCounter -= cyclesPerSample
            collectSample()
        }
    }
    
    func tickFrameSquencer() {
        guard isOn else { return }
        divCounter += 1
        
        if (divCounter % 2) == 0 {
            tick256Hz()
        }
        
        if (divCounter % 4) == 0 {
            tick128Hz()
        }
        
        if (divCounter % 8) == 0 {
            tick64Hz()
            divCounter = 0
        }
    }
    
    private func tick64Hz() {
        channel1.tickAmplitudeSweepCounter()
        channel2.tickAmplitudeSweepCounter()
        channel4.tickAmplitudeSweepCounter()
    }
    
    private func tick128Hz() {
        channel1.tickWavelengthSweepCounter()
    }
    
    private func tick256Hz() {
        channel1.tickLengthTimer()
        channel2.tickLengthTimer()
        channel3.tickLengthTimer()
        channel4.tickLengthTimer()
    }
}

// MARK: - Sample Mixing

extension APU {
    
    private func collectSample() {
        let channel1Sample = channel1.dacOutput()
        let channel2Sample = channel2.dacOutput()
        let channel3Sample = channel3.dacOutput()
        let channel4Sample = channel4.dacOutput()
        
        let leftChannelSamples: [Float] = [
            channel1Left ? channel1Sample : 0,
            channel2Left ? channel2Sample : 0,
            channel3Left ? channel3Sample : 0,
            channel4Left ? channel4Sample : 0,
        ]
        let leftSample = Self.mixChannelSamples(samples: leftChannelSamples, rawVolume: leftVolume)
        
        let rightChannelSamples: [Float] = [
            channel1Right ? channel1Sample : 0,
            channel2Right ? channel2Sample : 0,
            channel3Right ? channel3Sample : 0,
            channel4Right ? channel4Sample : 0,
        ]
        let rightSample = Self.mixChannelSamples(samples: rightChannelSamples, rawVolume: rightVolume)
        
        interleavedSampleBuffer.append(leftSample)
        interleavedSampleBuffer.append(rightSample)
        
        if isSampleBufferFull {
            isDrainingSamples = true
            synth.playSamples(interleavedSampleBuffer) { [weak self] in
                self?.interleavedSampleBuffer.removeAll()
                self?.isDrainingSamples = false
            }
        }
    }
    
    private static func mixChannelSamples(samples: [Float], rawVolume: UInt8) -> Float {
        let unmixedSample = samples.reduce(.zero, +) / 4
        let volumeMultiplier = (rawVolume + 1) / 8 // Use volume percentage to ensure sample remains in range of -1.0...1.0
        return unmixedSample * Float(volumeMultiplier)
    }
}

// MARK: - NR50: Master Volume

extension APU {
    
    private var rightVolume: UInt8 {
        nr50 & 0b111
    }
    
    private var leftVolume: UInt8 {
        (nr50 & 0b0111_0000) >> 4
    }
}

// MARK: - NR51: Sound Panning

extension APU {
    
    private var channel1Right: Bool {
        nr51.checkBit(0)
    }
    
    private var channel1Left: Bool {
        nr51.checkBit(4)
    }
    
    private var channel2Right: Bool {
        nr51.checkBit(1)
    }
    
    private var channel2Left: Bool {
        nr51.checkBit(5)
    }
    
    private var channel3Right: Bool {
        nr51.checkBit(2)
    }
    
    private var channel3Left: Bool {
        nr51.checkBit(6)
    }
    
    private var channel4Right: Bool {
        nr51.checkBit(3)
    }
    
    private var channel4Left: Bool {
        nr51.checkBit(7)
    }
}

// MARK: - NR52: Sound On/Off

extension APU {
    
    private func getNR52() -> UInt8 {
        var byte: UInt8 = 0
        if isOn { byte.setBit(0) }
        if channel4.isEnabled { byte.setBit(3) }
        if channel3.isEnabled { byte.setBit(2) }
        if channel2.isEnabled { byte.setBit(1) }
        if channel1.isEnabled { byte.setBit(0) }
        return byte
    }
    
    private func setNR52(_ nr52: UInt8) {
        // Writing to NR52 only affects AllSoundOn/Off flag for APU, and does not affect the enabled flags for each individual channel
        isOn = nr52.checkBit(7)
        
        if !isOn {
            divCounter = 0
            
            nr50 = 0
            nr51 = 0
            
            Memory.addressChannel1Range.forEach {
                channel1.write(0, address: $0)
            }
            
            Memory.addressChannel2Range.forEach {
                channel2.write(0, address: $0)
            }
            
            Memory.addressChannel3Range.forEach {
                channel3.write(0, address: $0)
            }
            
            Memory.addressChannel3WavePatternsRange.forEach {
                channel3.write(0, address: $0)
            }
            
            Memory.addressChannel4Range.forEach {
                channel4.write(0, address: $0)
            }
        }
    }
}
