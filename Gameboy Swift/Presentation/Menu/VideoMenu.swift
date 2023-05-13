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
            initialIsOnValue: GameBoy.instance.settings.useExtendedResolution
        ) { isOn in
            GameBoy.instance.settings.useExtendedResolution = isOn
        }
        let renderTilesSwitch = SwitchMenuItem(
            title: "Render Tiles",
            initialIsOnValue: GameBoy.instance.settings.renderTiles
        ) { isOn in
            GameBoy.instance.settings.renderTiles = isOn
        }
        let renderWindowSwitch = SwitchMenuItem(
            title: "Render Window",
            initialIsOnValue: GameBoy.instance.settings.renderWindow
        ) { isOn in
            GameBoy.instance.settings.renderWindow = isOn
        }
        let renderSpritesSwitch = SwitchMenuItem(
            title: "Render Sprites",
            initialIsOnValue: GameBoy.instance.settings.renderSprites
        ) { isOn in
            GameBoy.instance.settings.renderSprites = isOn
        }
        
        let blackAndWhitePaletteButton = CommonMenuItem(title: "Black And White") { [weak self] in
            GameBoy.instance.settings.colourPalette = .blackAndWhite
            self?.reloadItems()
        }
        let dmgPaletteButton = CommonMenuItem(title: "DMG") { [weak self] in
            GameBoy.instance.settings.colourPalette = .dmg
            self?.reloadItems()
        }
        let pocketPaletteButton = CommonMenuItem(title: "Pocket") { [weak self] in
            GameBoy.instance.settings.colourPalette = .pocket
            self?.reloadItems()
        }
        
        let colour1Slider = RGBASliderMenuItem(
            title: "Colour ID 0",
            initialRGBAValue: GameBoy.instance.settings.colourPalette.colour0
        ) { newValue in
            GameBoy.instance.settings.colourPalette.colour0 = newValue
        }
        let colour2Slider = RGBASliderMenuItem(
            title: "Colour ID 1",
            initialRGBAValue: GameBoy.instance.settings.colourPalette.colour1
        ) { newValue in
            GameBoy.instance.settings.colourPalette.colour1 = newValue
        }
        let colour3Slider = RGBASliderMenuItem(
            title: "Colour ID 2",
            initialRGBAValue: GameBoy.instance.settings.colourPalette.colour2
        ) { newValue in
            GameBoy.instance.settings.colourPalette.colour2 = newValue
        }
        let colour4Slider = RGBASliderMenuItem(
            title: "Colour ID 3",
            initialRGBAValue: GameBoy.instance.settings.colourPalette.colour3
        ) { newValue in
            GameBoy.instance.settings.colourPalette.colour3 = newValue
        }
        
        items = [
            extendedResolutionSwitch,
            renderTilesSwitch,
            renderWindowSwitch,
            renderSpritesSwitch,
            .separator(),
            blackAndWhitePaletteButton,
            dmgPaletteButton,
            pocketPaletteButton,
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
