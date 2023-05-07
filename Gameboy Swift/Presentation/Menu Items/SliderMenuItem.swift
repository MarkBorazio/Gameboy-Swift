//
//  SliderMenuItem.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/5/2023.
//

import Cocoa

class SliderMenuItem: NSMenuItem {
    
    private var onNewValue: ((UInt32) -> Void)?
    private let sliderView = NSSlider(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
    
    convenience init(value: UInt32, onNewValue: @escaping ((UInt32) -> Void)) {
        self.init()
        
        self.onNewValue = onNewValue
        
        sliderView.minValue = Double(UInt32.min)
        sliderView.maxValue = Double(UInt32.max)
        sliderView.doubleValue = Double(value)
        
        sliderView.target = self
        sliderView.action = #selector(onNewValueReceived)

        view = sliderView
    }
    
    @objc private func onNewValueReceived() {
        let newValue = UInt32(sliderView.doubleValue)
        onNewValue?(newValue)
    }
}
