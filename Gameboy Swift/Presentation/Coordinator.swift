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
        NSApplication.shared.mainMenu = MainMenu()
        
        window.backgroundColor = .black
        window.center()
        window.delegate = self
        window.contentViewController = ViewController()
        window.isReleasedWhenClosed = false
    }
    
    func presentFileSelector() {
        stopGameBoy()
        window.close()
        
        let dialog = NSOpenPanel()

        dialog.title = "Select a Game Boy ROM"
        dialog.showsResizeIndicator = true
        dialog.allowsMultipleSelection = false
        dialog.canChooseDirectories = false

        let response = dialog.runModal() // Seems to pause everything until dismissed.
        
        guard response == NSApplication.ModalResponse.OK else {
            // User clicked on "Cancel"
            return
        }
        
        guard let url = dialog.url else {
            presentWarningModal(title: "Error", message: "Failed to access ROM file")
            return
        }
        
        startGameBoy(romURL: url)
    }
    
    func startGameBoy(romURL: URL) {
        do {
            try GameBoy.instance.loadCartridge(romURL: romURL, skipBootROM: true)
        } catch {
            presentWarningModal(title: "Error", message: "Failed to load cartridge. Got error: \(error).")
            return
        }
        
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
        presentWarningModal(title: "Error", message: message)
        objc_terminate()
    }
    
    func quit() {
        stopGameBoy()
        NSApp.terminate(self)
    }
    
    func presentWarningModal(title: String, message: String?) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message ?? ""
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

extension Coordinator: NSWindowDelegate {
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        stopGameBoy()
        return true
    }
}
