//
//  RGBASliderMenuItem.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/5/2023.
//

import Cocoa

class RGBASliderMenuItem: NSMenuItem {
    
    private var onNewValue: ((UInt32) -> Void)?
    
    private let redSliderView = NSSlider()
    private let greenSliderView = NSSlider()
    private let blueSliderView = NSSlider()
    private let alphaSliderView = NSSlider()
    
    convenience init(title: String, initialRGBAValue: UInt32, onNewValue: @escaping ((UInt32) -> Void)) {
        self.init()
        
        self.onNewValue = onNewValue
        
        [redSliderView, greenSliderView, blueSliderView, alphaSliderView].forEach {
            $0.minValue = Double(UInt8.min)
            $0.maxValue = Double(UInt8.max)
            $0.target = self
            $0.action = #selector(onNewValueReceived)
        }
        
        alphaSliderView.trackFillColor = .white
        redSliderView.trackFillColor = .red
        greenSliderView.trackFillColor = .green
        blueSliderView.trackFillColor = .blue
        
        alphaSliderView.doubleValue = Double((initialRGBAValue >> 24) & 0xFF)
        blueSliderView.doubleValue = Double((initialRGBAValue >> 16) & 0xFF)
        greenSliderView.doubleValue = Double((initialRGBAValue >> 8) & 0xFF)
        redSliderView.doubleValue = Double((initialRGBAValue) & 0xFF)
        
        let stackView = NSStackView(views: [
            NSTextField(labelWithString: title),
            Self.constructSliderWithTitleView(title: "Alpha", slider: alphaSliderView),
            Self.constructSliderWithTitleView(title: "Red", slider: redSliderView),
            Self.constructSliderWithTitleView(title: "Green", slider: greenSliderView),
            Self.constructSliderWithTitleView(title: "Blue", slider: blueSliderView)
        ])
        stackView.orientation = .vertical
        
        let containerView = Self.embedInContainerView(stackView)
        view = containerView
    }
    
    @objc private func onNewValueReceived() {
        let alpha = UInt8(alphaSliderView.doubleValue)
        let red = UInt8(redSliderView.doubleValue)
        let green = UInt8(greenSliderView.doubleValue)
        let blue = UInt8(blueSliderView.doubleValue)
        
        let newValue = UInt32(bytes: [red, green, blue, alpha])!
        onNewValue?(newValue)
    }
    
    private static func constructSliderWithTitleView(title: String, slider: NSSlider) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        
        NSLayoutConstraint.activate([
            titleLabel.widthAnchor.constraint(equalToConstant: 50),
        ])
        
        let stackView = NSStackView(views: [
            titleLabel,
            slider
        ])
        stackView.orientation = .horizontal
        
        return stackView
    }
}
