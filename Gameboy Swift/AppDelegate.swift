//
//  AppDelegate.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Cocoa

// TODO:
// - Fix audio issues in Pokemon Gold
// - Implement Saving and save states
// - Implement serial interrupts ???
// - Implement file system for opening roms (and displaying name in window)
// - Remove singleton structure and clean things up

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let testRoms: [String] = [
        "cpu_instrs",
        "01-special", // Passes
        "02-interrupts", // Passes
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
        "Pokemon Blue",
        "Pokemon Gold"
    ]

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let rom = try! Cartridge(fileName: games[3])
        MMU.shared.loadCartridge(cartridge: rom, skipBootRom: true)
        MasterClock.shared.startTicking()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

