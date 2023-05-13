//
//  AudioMenu.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 13/5/2023.
//

import Cocoa

class AudioMenu: NSMenu {
    
    init() {
        super.init(title: "Audio")
        delegate = self
        reloadItems()
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func reloadItems() {
        let muteSwitch = SwitchMenuItem(
            title: "Mute",
            initialIsOnValue: GameBoy.instance.debugProperties.isMuted
        ) { isOn in
            GameBoy.instance.debugProperties.isMuted = isOn
        }
        let channel1Switch = SwitchMenuItem(
            title: "Channel 1",
            initialIsOnValue: GameBoy.instance.debugProperties.isChannel1Enabled
        ) { isOn in
            GameBoy.instance.debugProperties.isChannel1Enabled = isOn
        }
        let channel2Switch = SwitchMenuItem(
            title: "Channel 2",
            initialIsOnValue: GameBoy.instance.debugProperties.isChannel2Enabled
        ) { isOn in
            GameBoy.instance.debugProperties.isChannel2Enabled = isOn
        }
        let channel3Switch = SwitchMenuItem(
            title: "Channel 3",
            initialIsOnValue: GameBoy.instance.debugProperties.isChannel3Enabled
        ) { isOn in
            GameBoy.instance.debugProperties.isChannel3Enabled = isOn
        }
        let channel4Switch = SwitchMenuItem(
            title: "Channel 4",
            initialIsOnValue: GameBoy.instance.debugProperties.isChannel4Enabled
        ) { isOn in
            GameBoy.instance.debugProperties.isChannel4Enabled = isOn
        }
        
        items = [
            muteSwitch,
            .separator(),
            channel1Switch,
            channel2Switch,
            channel3Switch,
            channel4Switch
        ]
    }
}

extension AudioMenu: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        reloadItems()
    }
}
