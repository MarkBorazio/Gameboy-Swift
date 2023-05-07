//
//  AppDelegate.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Cocoa

// TODO:
// - Add separate debug sliders for each RGB value for each colour
// - Add debug menu item to open saves folder
// - Add something to PPU/MasterClock to make sure that frame is drawn only when it completes
// - Continue updating APU to pass more tests
// - Move to Metal rendering?
// - Update README

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Coordinator.instance.presentFileSelector()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        Coordinator.instance.stopGameBoy()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
