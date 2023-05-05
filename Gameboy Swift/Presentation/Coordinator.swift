//
//  Coordinator.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 5/5/2023.
//

import Cocoa

class Coordinator {
    
    static let instance = Coordinator()
    
    let window: NSWindow
    
    private init() {
        window = NSWindow(
            contentRect: NSMakeRect(0, 0, 0, 0),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
    }
    
    func presentFileSelector() {
        let dialog = NSOpenPanel()

        dialog.title = "Select a Game Boy ROM"
        dialog.showsResizeIndicator = true
        dialog.allowsMultipleSelection = false
        dialog.canChooseDirectories = false

        let response = dialog.runModal()
        
        guard response == NSApplication.ModalResponse.OK else {
            // User clicked on "Cancel"
            return
        }
        
        guard let url = dialog.url else {
            // No idea
            return
        }
        
        startGameBoy(romURL: url)
    }
    
    func startGameBoy(romURL: URL) {
        window.contentViewController = ViewController()
        window.title = romURL.deletingPathExtension().lastPathComponent
        window.makeKeyAndOrderFront(nil)
        
        let rom = try! Cartridge(fileURL: romURL) // TODO: Handle error
        MMU.shared.loadCartridge(cartridge: rom, skipBootRom: true)
        MasterClock.shared.startTicking()
    }
}
