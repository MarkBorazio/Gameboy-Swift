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
            range: 1...8,
            initialValue: GameBoy.instance.debugProperties.clockMultiplier
        ) { multiplier in
            GameBoy.instance.debugProperties.clockMultiplier = multiplier
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
