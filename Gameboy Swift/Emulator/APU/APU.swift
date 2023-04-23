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
    
    private var divCounter = 0
    
    private let channel1: SoundChannel1
    
    init() {
        channel1 = SoundChannel1(deltaTime: synth.deltaTime)
        
        synth.attachSourceNode(channel1.sourceNode)
        synth.volume = 0.1
        synth.start()
    }
    
    func read(address: UInt16) -> UInt8 {
        print("TODO: APU.read()")
        return 0
    }
    
    func write(_ value: UInt8, address: UInt16) {
        switch address {
        case Memory.addressChannel1Range: channel1.write(value, address: address)
        default: print("TODO: APU.write(\(value), address: \(address))")
        }
    }
    
    func tick() {
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
    }
    
    private func tick128Hz() {
        channel1.tickWavelengthSweepCounter()
    }
    
    private func tick256Hz() {
        channel1.tickLengthTimer()
    }
}
