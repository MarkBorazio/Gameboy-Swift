//
//  SwitchMenuItem.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/5/2023.
//

import Cocoa

class SwitchMenuItem: NSMenuItem {
    
    private var onTap: ((Bool) -> Void)?
    let switchView = NSSwitch()
    
    override var isEnabled: Bool {
        get { super.isEnabled }
        set {
            super.isEnabled = newValue
            switchView.isEnabled = newValue
        }
    }
    
    convenience init(title: String, initialIsOnValue: Bool, onTap: @escaping ((Bool) -> Void)) {
        self.init()
        
        self.onTap = onTap
        
        switchView.state = initialIsOnValue ? .on : .off
        switchView.target = self
        switchView.action = #selector(switchTapped)
        switchView.setContentHuggingPriority(.required, for: .horizontal)
        
        let titleLabel = NSTextField(labelWithString: title)
        
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
