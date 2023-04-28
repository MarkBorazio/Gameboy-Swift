//
//  APU.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 23/4/2023.
//

import Foundation

class APU {
    
    static let shared = APU()
    private let synth = Synth()
    
    private var nr52: UInt8 = 0
    
    private var divCounter = 0
    private var isOn = false
    
    private let channel1: SoundChannel1
    private let channel2: SoundChannel2
    
    private var sampleBuffer: [Float] = []
    private var sampleCounter = 0
    var isDrainingSamples = false
    var isSampleBufferFull: Bool {
        sampleBuffer.count >= 512
    }
    
    init() {
        channel1 = SoundChannel1()
        channel2 = SoundChannel2()
        
        synth.volume = 0.1
        synth.start()
    }
    
    func read(address: UInt16) -> UInt8 {
        switch address {
        case Memory.addressChannel1Range: return channel1.read(address: address)
        case Memory.addressChannel2Range: return channel2.read(address: address)
        default: return 0 //print("TODO: APU.read(address: \(address.hexString()))")
        }
    }
    
    func write(_ value: UInt8, address: UInt16) {
        if address == Memory.addressNR52 {
            updateSoundOnOff(value: value)
        } else {
            guard isOn else { return }
            
            switch address {
            case Memory.addressChannel1Range: channel1.write(value, address: address)
            case Memory.addressChannel2Range: channel2.write(value, address: address)
            default: break //print("TODO: APU.write(\(value), address: \(address.hexString()))")
            }
        }

    }
    
    func tick(clockCycles: Int) {
        guard isOn else { return }
        channel1.tickFrequencyTimer(clockCycles: clockCycles)
        channel2.tickFrequencyTimer(clockCycles: clockCycles)
        
        sampleCounter += clockCycles
        if sampleCounter >= Self.cyclesPerSample {
            sampleCounter -= Self.cyclesPerSample
            collectSample()
        }
    }
    
    private func collectSample() {
        let sample = (channel1.dacOutput() + channel2.dacOutput()) / 2
        sampleBuffer.append(sample)
        
        if isSampleBufferFull {
            isDrainingSamples = true
            synth.playSamples(sampleBuffer) { [weak self] in
                self?.sampleBuffer.removeAll()
                self?.isDrainingSamples = false
            }
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
    }
    
    private func tick128Hz() {
        channel1.tickWavelengthSweepCounter()
    }
    
    private func tick256Hz() {
        channel1.tickLengthTimer()
        channel2.tickLengthTimer()
    }
}

extension APU {
    
    private func updateSoundOnOff(value: UInt8) {
        nr52 = value
        let allSoundOn = value.checkBit(7)
        
        isOn = allSoundOn
        if !allSoundOn {
            divCounter = 0 // Not sure about this one
            
            channel1.write(0, address: Memory.addressNR10)
            channel1.write(0, address: Memory.addressNR11)
            channel1.write(0, address: Memory.addressNR12)
            channel1.write(0, address: Memory.addressNR13)
            channel1.write(0, address: Memory.addressNR14)
            
            channel2.write(0, address: Memory.addressNR21)
            channel2.write(0, address: Memory.addressNR22)
            channel2.write(0, address: Memory.addressNR23)
            channel2.write(0, address: Memory.addressNR24)
        }
    }
}

// MARK: - Constants

extension APU {
    
    private static let cyclesPerSample = 22 // M-Cycles
}
