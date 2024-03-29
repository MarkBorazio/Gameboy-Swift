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
        case Memory.addressNR20: return 0xFF // Write Only
        case Memory.addressNR21: return nrX1 | 0x3F
        case Memory.addressNR22: return nrX2
        case Memory.addressNR23: return 0xFF // Write Only
        case Memory.addressNR24: return nrX4 | 0xBF
        default: Coordinator.instance.crash(message: "Unknown SoundChannel2 read address received. Got \(address.hexString()).")
        }
    }
    
    func write(_ value: UInt8, address: UInt16) {
        switch address {
        case Memory.addressNR20: nrX0 = value
        case Memory.addressNR21: nrX1 = value
        case Memory.addressNR22: nrX2 = value
        case Memory.addressNR23: nrX3 = value
        case Memory.addressNR24: nrX4 = value
        default: Coordinator.instance.crash(message: "Unknown SoundChannel2 write address received. Got \(address.hexString()).")
        }
    }
    
    override func tickWavelengthSweepCounter() {
        Coordinator.instance.crash(message: "Channel 2 does not support wavelength sweep.")
    }
}
