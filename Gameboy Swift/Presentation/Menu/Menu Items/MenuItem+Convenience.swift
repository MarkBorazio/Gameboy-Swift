//
//  MenuItem+Convenience.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 9/5/2023.
//

import Cocoa

extension NSMenuItem {

    static func embedInContainerView(_ view: NSView) -> NSView {
        let containerView = NSView()
        containerView.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 10),
            view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -10),
            view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            containerView.widthAnchor.constraint(equalToConstant: 200)
        ])
        containerView.translatesAutoresizingMaskIntoConstraints = false
        return containerView
    }
    
    static func constructSliderWithTitleView(title: String, slider: NSSlider) -> NSView {
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
