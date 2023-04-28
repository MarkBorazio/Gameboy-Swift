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
class SoundChannel2: SquareWaveChannel {
    
    func read(address: UInt16) -> UInt8 {
        switch address {
        case Memory.addressNR21: return nrX1 & 0b1100_0000
        case Memory.addressNR22: return nrX2
        case Memory.addressNR23: return nrX3
        case Memory.addressNR24: return nrX4 & 0b0100_0000
        default: fatalError("Unknown SoundChannel2 read address received. Got \(address.hexString()).")
        }
    }
    
    func write(_ value: UInt8, address: UInt16) {
        switch address {
        case Memory.addressNR21: nrX1 = value
        case Memory.addressNR22: nrX2 = value
        case Memory.addressNR23: nrX3 = value
        case Memory.addressNR24: nrX4 = value
        default: fatalError("Unknown SoundChannel2 write address received. Got \(address.hexString()).")
        }
    }
    
    override func tickWavelengthSweepCounter() {
        fatalError("Channel 2 does not support wavelength sweep.")
    }
}
