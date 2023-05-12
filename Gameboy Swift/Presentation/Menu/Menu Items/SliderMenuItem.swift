//
//  SliderMenuItem.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 13/5/2023.
//

import Cocoa

class SliderMenuItem: NSMenuItem {
    
    private var onNewValue: ((Double) -> Void)?
    
    private let sliderView = NSSlider()
    
    convenience init(
        range: ClosedRange<Double>,
        initialValue: Double,
        onNewValue: @escaping ((Double) -> Void)
    ) {
        self.init()
        
        self.onNewValue = onNewValue
        
        sliderView.minValue = range.lowerBound
        sliderView.maxValue = range.upperBound
        sliderView.doubleValue = initialValue
        
        sliderView.target = self
        sliderView.action = #selector(onNewValueReceived)
        
        let sliderWithTitleView = Self.constructSliderWithTitleView(title: "Speed", slider: sliderView)
        let containerView = Self.embedInContainerView(sliderWithTitleView)
        view = containerView
    }
    
    @objc private func onNewValueReceived() {
        onNewValue?(sliderView.doubleValue)
    }
}

