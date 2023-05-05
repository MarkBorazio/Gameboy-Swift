//
//  AppDelegate.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Cocoa

// TODO:
// - Implement Saving and save states
// - Implement serial interrupts and write unit tests for test ROMs
// - Look into addressing sound popping
// - Remove singleton structure and clean things up

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        Coordinator.instance.presentFileSelector()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}
