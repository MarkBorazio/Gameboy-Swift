//
//  Coordinator.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 5/5/2023.
//

import Cocoa

class Coordinator: NSObject {
    
    static let instance = Coordinator()
    
    let window = NSWindow(
        contentRect: NSMakeRect(0, 0, 0, 0),
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    
    private override init() {
        super.init()
        
        window.backgroundColor = .black
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        
        NSApplication.shared.mainMenu = MenuFactory.constructMenu()
    }
    
    func presentFileSelector() {
        let dialog = NSOpenPanel()

        dialog.title = "Select a Game Boy ROM"
        dialog.showsResizeIndicator = true
        dialog.allowsMultipleSelection = false
        dialog.canChooseDirectories = false

        let response = dialog.runModal() // Seems to pause thread until dismissed.
        
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
        try! GameBoy.instance.loadCartridge(romURL: romURL, skipBootROM: true)
        
        window.contentViewController = ViewController()
        window.title = romURL.deletingPathExtension().lastPathComponent
        window.makeKeyAndOrderFront(nil)
        
        GameBoy.instance.clock.startTicking()
    }
    
    func stopGameBoy() {
        GameBoy.instance.saveDataToFile()
        GameBoy.instance.removeCartridge()
    }
    
    func crash(message: String) -> Never {
        stopGameBoy()
        
        let alert = NSAlert()
        alert.messageText = "Error"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        objc_terminate()
    }
}

extension Coordinator: NSWindowDelegate {
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        stopGameBoy()
        return true
    }
}
