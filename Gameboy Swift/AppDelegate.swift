//
//  AppDelegate.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Cocoa

// TODO:
// - Window internal line counter (will break extended resolution mode)
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
}
