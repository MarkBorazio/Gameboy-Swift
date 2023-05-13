//
//  VideoMenu.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 13/5/2023.
//

import Cocoa

class VideoMenu: NSMenu {
    
    init() {
        super.init(title: "Video")
        delegate = self
        reloadItems()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func reloadItems() {
        let extendedResolutionSwitch = SwitchMenuItem(
            title: "Extended Resolution",
            initialIsOnValue: GameBoy.instance.debugProperties.useExtendedResolution
        ) { isOn in
            GameBoy.instance.debugProperties.useExtendedResolution = isOn
        }
        let renderTilesSwitch = SwitchMenuItem(
            title: "Render Tiles",
            initialIsOnValue: GameBoy.instance.debugProperties.renderTiles
        ) { isOn in
            GameBoy.instance.debugProperties.renderTiles = isOn
        }
        let renderWindowSwitch = SwitchMenuItem(
            title: "Render Window",
            initialIsOnValue: GameBoy.instance.debugProperties.renderWindow
        ) { isOn in
            GameBoy.instance.debugProperties.renderWindow = isOn
        }
        let renderSpritesSwitch = SwitchMenuItem(
            title: "Render Sprites",
            initialIsOnValue: GameBoy.instance.debugProperties.renderSprites
        ) { isOn in
            GameBoy.instance.debugProperties.renderSprites = isOn
        }
        
        let colour1Slider = RGBASliderMenuItem(
            title: "Colour ID 0",
            initialRGBAValue: ColourPalette.white
        ) { newValue in
            GameBoy.instance.debugProperties.colour1 = newValue
        }
        let colour2Slider = RGBASliderMenuItem(
            title: "Colour ID 1",
            initialRGBAValue: ColourPalette.lightGrey
        ) { newValue in
            GameBoy.instance.debugProperties.colour2 = newValue
        }
        let colour3Slider = RGBASliderMenuItem(
            title: "Colour ID 2",
            initialRGBAValue: ColourPalette.darkGrey
        ) { newValue in
            GameBoy.instance.debugProperties.colour3 = newValue
        }
        let colour4Slider = RGBASliderMenuItem(
            title: "Colour ID 3",
            initialRGBAValue: ColourPalette.black
        ) { newValue in
            GameBoy.instance.debugProperties.colour4 = newValue
        }
        
        items = [
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
    }
}

extension VideoMenu: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        reloadItems()
    }
}
