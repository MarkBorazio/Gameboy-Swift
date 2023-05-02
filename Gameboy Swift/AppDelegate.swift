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
        "cpu_instrs",
        "01-special", // Passes
        "02-interrupts", // Timer doesn't work
        "03-op sp,hl", // Passes
        "04-op r,imm", // Passes
        "05-op rp", // Passes
        "06-ld r,r", // Passes
        "07-jr,jp,call,ret,rst", // Passes
        "08-misc instrs", // Passes
        "09-op r,r", // Passes
        "10-bit ops", // Passes
        "11-op a,(hl)", // Passes,
        "halt_bug"
    ]
    
    let games = [
        "Tetris",
        "Super Mario Land",
        "Pokemon Blue"
    ]

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let rom = try! Cartridge(fileName: testRoms[12])
        MMU.shared.loadCartridge(cartridge: rom, skipBootRom: true)
        MasterClock.shared.startTicking()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

