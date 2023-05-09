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
        let extendedResolutionSwitch = SwitchMenuItem(title: "Extended Resolution", initialIsOnValue: false) { isOn in
            GameBoy.instance.debugProperties.useExtendedResolution = isOn
        }
        
        let channel1Switch = SwitchMenuItem(title: "Channel 1", initialIsOnValue: true) { isOn in
            GameBoy.instance.debugProperties.isChannel1Enabled = isOn
        }
        let channel2Switch = SwitchMenuItem(title: "Channel 2", initialIsOnValue: true) { isOn in
            GameBoy.instance.debugProperties.isChannel2Enabled = isOn
        }
        let channel3Switch = SwitchMenuItem(title: "Channel 3", initialIsOnValue: true) { isOn in
            GameBoy.instance.debugProperties.isChannel3Enabled = isOn
        }
        let channel4Switch = SwitchMenuItem(title: "Channel 4", initialIsOnValue: true) { isOn in
            GameBoy.instance.debugProperties.isChannel4Enabled = isOn
        }
        
        let colour1Slider = RGBASliderMenuItem(title: "Colour ID 0", initialRGBAValue: ColourPalette.white) { newValue in
            GameBoy.instance.debugProperties.colour1 = newValue
        }
        let colour2Slider = RGBASliderMenuItem(title: "Colour ID 1", initialRGBAValue: ColourPalette.lightGrey) { newValue in
            GameBoy.instance.debugProperties.colour2 = newValue
        }
        let colour3Slider = RGBASliderMenuItem(title: "Colour ID 2", initialRGBAValue: ColourPalette.darkGrey) { newValue in
            GameBoy.instance.debugProperties.colour3 = newValue
        }
        let colour4Slider = RGBASliderMenuItem(title: "Colour ID 3", initialRGBAValue: ColourPalette.black) { newValue in
            GameBoy.instance.debugProperties.colour4 = newValue
        }
        
        let debugMenu = NSMenu(title: "Debug")
        debugMenu.items = [
            extendedResolutionSwitch,
            .separator(),
            channel1Switch,
            channel2Switch,
            channel3Switch,
            channel4Switch,
            .separator(),
            colour1Slider,
            .separator(),
            colour2Slider,
            .separator(),
            colour3Slider,
            .separator(),
            colour4Slider
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
