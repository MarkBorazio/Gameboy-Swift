//
//  SwitchMenuItem.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/5/2023.
//

import Cocoa

class SwitchMenuItem: NSMenuItem {
    
    private var onTap: ((Bool) -> Void)?
    private let switchView = NSSwitch()
    
    convenience init(title: String, initialIsOnValue: Bool, onTap: @escaping ((Bool) -> Void)) {
        self.init()
        
        self.onTap = onTap
        
        switchView.state = initialIsOnValue ? .on : .off
        switchView.target = self
        switchView.action = #selector(switchTapped)
        
        let titleLabel = NSTextField(labelWithString: title)
        NSLayoutConstraint.activate([
            titleLabel.widthAnchor.constraint(equalToConstant: 70)
        ])
        
        let stackView = NSStackView(views: [
            titleLabel,
            NSView(), // Spacer
            switchView
        ])
        stackView.orientation = .horizontal
        
        let containerView = Self.embedInContainerView(stackView)
        view = containerView
    }
    
    @objc private func switchTapped() {
        onTap?(switchView.state == .on)
    }
}
