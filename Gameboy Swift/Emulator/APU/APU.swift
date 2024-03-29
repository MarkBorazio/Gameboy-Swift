//
//  APU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 23/4/2023.
//

import Foundation

class APU {
    
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
    
    private var tCyclesPerSample: Int {
        let doubleVal = Double(GameBoy.instance.clock.multipliedTCyclesHz) / synth.sampleRate
        return Int(doubleVal.rounded(.awayFromZero))
    }
    
    private var interleavedSampleBuffer: [Float] = [] // L/R
    private var sampleCounter = 0
    private var isSampleBufferFull: Bool {
        interleavedSampleBuffer.count >= 1024 // 512 samples left and 512 samples right
    }
    
    private var divCounter = 0
    var isDrainingSamples = false
    
    init() {
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
            return nr52 | 0x70
            
        case Memory.addressChannel1Range:
            return channel1.read(address: address)
            
        case Memory.addressChannel2Range:
            return channel2.read(address: address)
            
        case Memory.addressChannel3Range, Memory.addressChannel3WavePatternsRange:
            return channel3.read(address: address)
            
        case Memory.addressChannel4Range:
            return channel4.read(address: address)
            
        case Memory.addressAPUUnusedRange:
            return 0xFF
            
        default:
            Coordinator.instance.crash(message: "Unhandled APU read address received. Got: \(address.hexString()).")
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
                
            case Memory.addressAPUUnusedRange:
                break
                
            default:
                Coordinator.instance.crash(message: "Unhandled APU write address received. Got: \(address.hexString()).")
            }
        }

    }
    
    func tick(tCycles: Int) {
        guard isOn else { return }
        channel1.tickFrequencyTimer(tCycles: tCycles)
        channel2.tickFrequencyTimer(tCycles: tCycles)
        channel3.tickFrequencyTimer(tCycles: tCycles)
        channel4.tickFrequencyTimer(tCycles: tCycles)
        
        sampleCounter += tCycles
        if sampleCounter >= tCyclesPerSample {
            sampleCounter -= tCyclesPerSample
            collectSample()
        }
    }
    
    /*
     Step   Length Ctr  Vol Env     Sweep
     ---------------------------------------
     0      Clock       -           -
     1      -           -           -
     2      Clock       -           Clock
     3      -           -           -
     4      Clock       -           -
     5      -           -           -
     6      Clock       -           Clock
     7      -           Clock       -
     ---------------------------------------
     Rate   256 Hz      64 Hz       128 Hz
     
     Ref: https://gbdev.gg8.se/wiki/articles/Gameboy_sound_hardware#Frame_Sequencer
    */
    func tickFrameSquencer() {
        guard isOn else { return }
        
        if (divCounter & 0x1) == 0 { // Every second step
            tick256Hz()
        }
        
        if (divCounter == 2 || divCounter == 6) { // Every fourth step
            tick128Hz()
        }
        
        if divCounter == 7 { // Every eighth step
            tick64Hz()
        }
        
        divCounter = (divCounter + 1) & 7 // Cycle from 0-7
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
        let settings = GameBoy.instance.settings
        
        let leftSample: Float
        let rightSample: Float
        
        if !settings.isMuted {
            let channel1Sample = channel1.dacOutput()
            let channel2Sample = channel2.dacOutput()
            let channel3Sample = channel3.dacOutput()
            let channel4Sample = channel4.dacOutput()
            
            let leftChannelSamples: [Float] = [
                channel1Left && settings.isChannel1Enabled ? channel1Sample : 0,
                channel2Left && settings.isChannel2Enabled ? channel2Sample : 0,
                channel3Left && settings.isChannel3Enabled ? channel3Sample : 0,
                channel4Left && settings.isChannel4Enabled ? channel4Sample : 0,
            ]
            
            let rightChannelSamples: [Float] = [
                channel1Right && settings.isChannel1Enabled ? channel1Sample : 0,
                channel2Right && settings.isChannel2Enabled ? channel2Sample : 0,
                channel3Right && settings.isChannel3Enabled ? channel3Sample : 0,
                channel4Right && settings.isChannel4Enabled ? channel4Sample : 0,
            ]
            
            leftSample = Self.mixChannelSamples(samples: leftChannelSamples, rawVolume: leftVolume)
            rightSample = Self.mixChannelSamples(samples: rightChannelSamples, rawVolume: rightVolume)
        } else {
            leftSample = 0
            rightSample = 0
        }
        
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
        let volumeMultiplier = Float(rawVolume + 1) / 8 // Use volume percentage to ensure sample remains in range of -1.0...1.0
        return unmixedSample * volumeMultiplier
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
        if isOn { byte.setBit(7) }
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
            
            // Don't clear wave RAM
            
            Memory.addressChannel4Range.forEach {
                channel4.write(0, address: $0)
            }
        }
    }
}
