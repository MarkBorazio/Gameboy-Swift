//
//  Menu+Convenience.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 13/5/2023.
//

import Cocoa

extension NSMenu {
    
    func setAllMenuItemsEnabled(isEnabled: Bool) {
        items.forEach {
            $0.isEnabled = isEnabled
            $0.submenu?.setAllMenuItemsEnabled(isEnabled: isEnabled)
        }
    }
}
