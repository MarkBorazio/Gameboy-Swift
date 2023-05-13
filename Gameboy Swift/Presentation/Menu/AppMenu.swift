//
//  AppMenu.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 13/5/2023.
//

import Cocoa

class AppMenu: NSMenu {
    
    init() {
        super.init(title: PlistValues.appName)
        
        let resetDebugMenuItem = CommonMenuItem(title: "Reset debug overrides") {
            GameBoy.instance.debugProperties = .init()
        }
        
        let quitMenuItem = CommonMenuItem(title: "Quit \(PlistValues.appName)", keyEquivalent: "q") {
            Coordinator.instance.quit()
        }
        
        items = [
            resetDebugMenuItem,
            .separator(),
            quitMenuItem
        ]
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
