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
        
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false
        
        setupMenuItem()
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

// MARK: - Menu Bar

extension Coordinator {
    
    private func setupMenuItem() {
        let appMenu = NSMenu()
        
        appMenu.items = [
            NSMenuItem(), // It seems that the first item always corresponds to the main App Name item
            constructDebugMenuItem()
        ]
        
        NSApplication.shared.mainMenu = appMenu
    }
    
    private func constructDebugMenuItem() -> NSMenuItem {
        let channel1Switch = SwitchMenuItem(isOn: true) { isOn in
            GameBoy.instance.debugProperties.isChannel1Enabled = isOn
        }
        let channel2Switch = SwitchMenuItem(isOn: true) { isOn in
            GameBoy.instance.debugProperties.isChannel2Enabled = isOn
        }
        let channel3Switch = SwitchMenuItem(isOn: true) { isOn in
            GameBoy.instance.debugProperties.isChannel3Enabled = isOn
        }
        let channel4Switch = SwitchMenuItem(isOn: true) { isOn in
            GameBoy.instance.debugProperties.isChannel4Enabled = isOn
        }
        
        let colour1Slider = SliderMenuItem(value: ColourPalette.white) { newValue in
            GameBoy.instance.debugProperties.colour1 = newValue
        }
        let colour2Slider = SliderMenuItem(value: ColourPalette.lightGrey) { newValue in
            GameBoy.instance.debugProperties.colour2 = newValue
        }
        let colour3Slider = SliderMenuItem(value: ColourPalette.darkGrey) { newValue in
            GameBoy.instance.debugProperties.colour3 = newValue
        }
        let colour4Slider = SliderMenuItem(value: ColourPalette.black) { newValue in
            GameBoy.instance.debugProperties.colour4 = newValue
        }
        
        let debugMenu = NSMenu(title: "Debug")
        debugMenu.items = [
            channel1Switch,
            channel2Switch,
            channel3Switch,
            channel4Switch,
            colour1Slider,
            colour2Slider,
            colour3Slider,
            colour4Slider,
        ]
        
        let debugMenuItem = NSMenuItem()
        debugMenuItem.submenu = debugMenu
        
        return debugMenuItem
    }
}

extension Coordinator: NSWindowDelegate {
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        stopGameBoy()
        return true
    }
}
