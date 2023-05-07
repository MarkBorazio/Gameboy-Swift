//
//  SwitchMenuItem.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/5/2023.
//

import Cocoa

class SwitchMenuItem: NSMenuItem {
    
    private var onTap: ((Bool) -> Void)?
    private let switchView = NSSwitch(frame: CGRect(x: 0, y: 0, width: 100, height: 30))
    
    convenience init(isOn: Bool, onTap: @escaping ((Bool) -> Void)) {
        self.init()
        
        self.onTap = onTap
        
        switchView.state = isOn ? .on : .off
        
        switchView.target = self
        switchView.action = #selector(switchTapped)
        
        view = switchView
    }
    
    @objc private func switchTapped() {
        onTap?(switchView.state == .on)
    }
}
