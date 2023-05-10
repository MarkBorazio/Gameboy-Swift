//
//  MenuFactory.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 10/5/2023.
//

import Cocoa

enum MenuFactory {
    
    static func constructMenu() -> NSMenu {
        let appMenu = NSMenu()
        
        appMenu.items = [
            NSMenuItem(), // It seems that the first item always corresponds to the main App Name item
            constructFileMenu(),
            constructVideoMenu(),
            constructAudioMenu()
        ]
        
        return appMenu
    }
    
    private static func constructFileMenu() -> NSMenuItem {
        let menu = NSMenu(title: "File")
        
        let openSavesFolderItem = CommonMenuItem(title: "Open Saves Folder") {
            do {
                let url = try GameBoy.getSavesFolderURL()
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                Coordinator.instance.presentWarningModal(title: "Failed to open saves folder.", message: nil)
            }
        }
        
        menu.items = [
            openSavesFolderItem
        ]
        
        let menuItem = NSMenuItem()
        menuItem.submenu = menu
        
        return menuItem
    }
    
    private static func constructVideoMenu() -> NSMenuItem {
        let extendedResolutionSwitch = SwitchMenuItem(title: "Extended Resolution", initialIsOnValue: false) { isOn in
            GameBoy.instance.debugProperties.useExtendedResolution = isOn
        }
        let renderTilesSwitch = SwitchMenuItem(title: "Render Tiles", initialIsOnValue: true) { isOn in
            GameBoy.instance.debugProperties.renderTiles = isOn
        }
        let renderWindowSwitch = SwitchMenuItem(title: "Render Window", initialIsOnValue: true) { isOn in
            GameBoy.instance.debugProperties.renderWindow = isOn
        }
        let renderSpritesSwitch = SwitchMenuItem(title: "Render Sprites", initialIsOnValue: true) { isOn in
            GameBoy.instance.debugProperties.renderSprites = isOn
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
        
        let menu = NSMenu(title: "Video")
        menu.items = [
            extendedResolutionSwitch,
            renderTilesSwitch,
            renderWindowSwitch,
            renderSpritesSwitch,
            .separator(),
            colour1Slider,
            .separator(),
            colour2Slider,
            .separator(),
            colour3Slider,
            .separator(),
            colour4Slider
        ]
        
        let menuItem = NSMenuItem()
        menuItem.submenu = menu
        
        return menuItem
    }
    
    private static func constructAudioMenu() -> NSMenuItem {
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
        
        let menu = NSMenu(title: "Audio")
        menu.items = [
            channel1Switch,
            channel2Switch,
            channel3Switch,
            channel4Switch
        ]
        
        let menuItem = NSMenuItem()
        menuItem.submenu = menu
        
        return menuItem
    }
}
