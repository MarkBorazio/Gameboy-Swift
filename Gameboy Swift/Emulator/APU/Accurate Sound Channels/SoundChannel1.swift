//
//  SoundChannel1.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 23/4/2023.
//

import Foundation
import AVFAudio

// Square Wave
// Same as Channel 2, but this has a wavelength sweep
class SoundChannel1: SquareWaveChannel {
    
    func read(address: UInt16) -> UInt8 {
        switch address {
        case Memory.addressNR10: return nrX0
        case Memory.addressNR21: return nrX1 & 0b1100_0000
        case Memory.addressNR22: return nrX2
        case Memory.addressNR23: return nrX3
        case Memory.addressNR24: return nrX4 & 0b0100_0000
        default: fatalError("Unknown SoundChannel2 read address received. Got \(address.hexString()).")
        }
    }
    
    func write(_ value: UInt8, address: UInt16) {
        switch address {
        case Memory.addressNR10: nrX0 = value
        case Memory.addressNR11: nrX1 = value
        case Memory.addressNR12: nrX2 = value
        case Memory.addressNR13: nrX3 = value
        case Memory.addressNR14: nrX4 = value
        default: fatalError("Unknown SoundChannel1 address received. Got \(address.hexString()).")
        }
    }
}
