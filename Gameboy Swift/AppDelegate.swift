//
//  AppDelegate.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let testRoms: [String] = [
        "01-special", // Fails at DAA
        "02-interrupts", // Timer doesn't work
        "03-op sp,hl", // Fails
        "04-op r,imm", // Fails
        "05-op rp", // Fails
        "06-ld r,r", // Fails
        "07-jr,jp,call,ret,rst", // Fails
        "08-misc instrs", // Fails
        "09-op r,r", // Fails (after a while)
        "10-bit ops", // Fails (after a while)
        "11-op a,(hl)" // Fails (after a while)
    ]

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let rom = try! ROM(fileName: testRoms[5])
        MMU.shared.loadRom(rom: rom, skipBootRom: true)
        MasterClock.shared.startTicking()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

