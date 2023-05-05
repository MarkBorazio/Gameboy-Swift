//
//  Coordinator.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 5/5/2023.
//

import Cocoa

class Coordinator: NSObject {
    
    static let instance = Coordinator()
    
    let window: NSWindow
    
    private override init() {
        window = NSWindow(
            contentRect: NSMakeRect(0, 0, 0, 0),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init()
        
        window.center()
        window.delegate = self
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
        
        let saveDataURL = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(romURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("gbswiftsave")
        
        let rom = try! Cartridge(fileURL: romURL, saveDataURL: saveDataURL) // TODO: Handle error
        MMU.shared.loadCartridge(cartridge: rom, skipBootRom: true)
        MasterClock.shared.startTicking()
        
        someURL = romURL
    }
    
    var someURL: URL?
}

extension Coordinator: NSWindowDelegate {
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard let someURL else { return true }
        
        let saveData = MMU.shared.getRAMSnapshot()
        
        let url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent(someURL.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("gbswiftsave")
        
        if (FileManager.default.createFile(atPath: url.path, contents: saveData, attributes: nil)) {
            print("File created successfully.")
        } else {
            print("File not created.")
        }
        
        return true
    }
}
