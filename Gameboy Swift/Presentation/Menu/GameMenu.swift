//
//  GameMenu.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 13/5/2023.
//

import Cocoa

class GameMenu: NSMenu {
    
    init() {
        super.init(title: "Game")
        delegate = self
        reloadItems()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func reloadItems() {
        let speedMultiplerSlider = SliderMenuItem(
            range: 0...8,
            initialValue: GameBoy.instance.settings.clockMultiplier
        ) { multiplier in
            GameBoy.instance.settings.clockMultiplier = multiplier
        }
        
        items = [
            speedMultiplerSlider
        ]
    }
}

extension GameMenu: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        reloadItems()
    }
}
