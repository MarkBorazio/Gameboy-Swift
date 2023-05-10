//
//  CommonMenuItem.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 11/5/2023.
//

import Cocoa

class CommonMenuItem: NSMenuItem {
    
    private var onTap: (() -> Void)?
    
    convenience init(title: String, onTap: @escaping (() -> Void)) {
        self.init(title: title, action: #selector(onTapWrapper), keyEquivalent: "")
        target = self
        self.onTap = onTap
    }
    
    @objc private func onTapWrapper() {
        onTap?()
    }
}
