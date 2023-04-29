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
    
    var sampleRate: Double { audioFormat.sampleRate }
    
    private let audioEngine: AVAudioEngine
    private let audioPlayerNode: AVAudioPlayerNode
    private let audioFormat: AVAudioFormat
    
    init() {
        audioEngine = AVAudioEngine()
        let outputNode = audioEngine.outputNode
        let format = outputNode.inputFormat(forBus: 0)
        let audioFormat = AVAudioFormat(
            commonFormat: format.commonFormat,
            sampleRate: format.sampleRate,
            channels: 1,
            interleaved: format.isInterleaved
        )!
        
        audioPlayerNode = AVAudioPlayerNode()
        self.audioFormat = audioFormat

        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: audioFormat)
        
        audioPlayerNode.volume = 1
        audioEngine.mainMixerNode.outputVolume = 1
    }
    
    func start() {
        do {
            try audioEngine.start()
            audioPlayerNode.play()
        } catch {
            fatalError("Failed to start Audio Engine. Got error: \(error).")
        }
    }
    
    func stop() {
        audioEngine.stop()
    }
    
    
    func playSamples(_ samples: [Float], completionHandler: @escaping AVAudioNodeCompletionHandler) {
        let frameCount = samples.count
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        for i in 0..<frameCount {
            buffer.floatChannelData?[0][i] = samples[i]
        }
        audioPlayerNode.scheduleBuffer(buffer, completionHandler: completionHandler)
    }
}

