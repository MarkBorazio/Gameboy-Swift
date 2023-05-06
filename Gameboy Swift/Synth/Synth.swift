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
        audioPlayerNode = AVAudioPlayerNode()
        let audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 48000,
            channels: 2,
            interleaved: false
        )!
        
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
            Coordinator.instance.crash(message: "Failed to start Audio Engine. Got error: \(error).")
        }
    }
    
    func stop() {
        audioEngine.stop()
    }

    
    /// interleavedSamples in the format of [L, R, L, R, ...]
    func playSamples(_ interleavedSamples: [Float], completionHandler: @escaping AVAudioNodeCompletionHandler) {
        let bufferSize = interleavedSamples.count / 2
        let frameCount = AVAudioFrameCount(bufferSize)
        
        let buffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        
        for i in 0..<bufferSize {
            let sampleIndex = i*2
            buffer.floatChannelData?[0][i] = interleavedSamples[sampleIndex]
            buffer.floatChannelData?[1][i] = interleavedSamples[sampleIndex + 1]
        }
        
        audioPlayerNode.scheduleBuffer(buffer, completionHandler: completionHandler)
    }
}

