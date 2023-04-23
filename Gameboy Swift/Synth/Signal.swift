//
//  Signal.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 23/4/2023.
//

import Foundation

typealias Signal = (_ frequency: Float, _ time: Float, _ dutyCycle: Double, _ amplitude: Float) -> Float

enum Oscillator {
    
    static let square: Signal = { frequency, time, dutyCycle, amplitude in
        let period = 1.0 / Double(frequency)
        let currentTime = fmod(Double(time), period)
        return ((currentTime / period) < dutyCycle) ? amplitude : -1.0 * amplitude
    }
}
