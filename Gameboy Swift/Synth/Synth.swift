//
//  Synth.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 23/4/2023.
//

import AVFoundation

class Synth {
    
    var volume: Float {
        set {
            audioEngine.mainMixerNode.outputVolume = newValue
        }
        get {
            audioEngine.mainMixerNode.outputVolume
        }
    }
    
    private var audioEngine: AVAudioEngine
    private let inputFormat: AVAudioFormat?
    let deltaTime: Float
    
    init() {
        audioEngine = AVAudioEngine()
        
        let format = audioEngine.outputNode.inputFormat(forBus: 0)
        deltaTime = Float(1 / format.sampleRate)
        
        inputFormat = AVAudioFormat(
            commonFormat: format.commonFormat,
            sampleRate: format.sampleRate,
            channels: 1,
            interleaved: format.isInterleaved
        )

        audioEngine.mainMixerNode.outputVolume = 0
    }
    
    func start() {
        do {
            try audioEngine.start()
        } catch {
            fatalError("Failed to start Audio Engine. Got error: \(error).")
        }
    }
    
    func stop() {
        audioEngine.stop()
    }
    
    func attachSourceNode(_ sourceNode: AVAudioSourceNode) {
        audioEngine.attach(sourceNode)
        audioEngine.connect(sourceNode, to: audioEngine.mainMixerNode, format: inputFormat)
        audioEngine.connect(audioEngine.mainMixerNode, to: audioEngine.outputNode, format: nil)
    }
}

