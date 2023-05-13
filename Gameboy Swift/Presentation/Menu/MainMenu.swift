//
//  MainMenu.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 13/5/2023.
//

import Cocoa

class MainMenu: NSMenu {
    
    var appMenu = AppMenu()
    var fileMenu = FileMenu()
    var gameMenu = GameMenu()
    var videoMenu = VideoMenu()
    var audioMenu = AudioMenu()
    
    override init(title: String) {
        super.init(title: title)
        
        items = [
            NSMenuItem(menu: appMenu, autoEnablesItems: false),
            NSMenuItem(menu: fileMenu, autoEnablesItems: false),
            NSMenuItem(menu: gameMenu, autoEnablesItems: false),
            NSMenuItem(menu: videoMenu, autoEnablesItems: false),
            NSMenuItem(menu: audioMenu, autoEnablesItems: false)
        ]
        autoenablesItems = false
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
