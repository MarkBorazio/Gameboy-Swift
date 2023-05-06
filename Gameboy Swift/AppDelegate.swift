//
//  AppDelegate.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Cocoa

// TODO:
// - Implement serial interrupts and write unit tests for test ROMs
// - Look into addressing sound popping

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
