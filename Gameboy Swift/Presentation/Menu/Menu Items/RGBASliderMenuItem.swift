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
    
    override var isEnabled: Bool {
        get { super.isEnabled }
        set {
            super.isEnabled = newValue
            [redSliderView, greenSliderView, blueSliderView, alphaSliderView].forEach {
                $0.isEnabled = newValue
            }
        }
    }
    
    var argbValue: UInt32 {
        get {
            let alpha = UInt8(alphaSliderView.doubleValue)
            let red = UInt8(redSliderView.doubleValue)
            let green = UInt8(greenSliderView.doubleValue)
            let blue = UInt8(blueSliderView.doubleValue)
            return UInt32(bytes: [red, green, blue, alpha])!
        }
        set {
            alphaSliderView.doubleValue = Double((newValue >> 24) & 0xFF)
            blueSliderView.doubleValue = Double((newValue >> 16) & 0xFF)
            greenSliderView.doubleValue = Double((newValue >> 8) & 0xFF)
            redSliderView.doubleValue = Double((newValue) & 0xFF)
        }
    }
    
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
        
        argbValue = initialRGBAValue
        
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
        onNewValue?(argbValue)
    }
}
