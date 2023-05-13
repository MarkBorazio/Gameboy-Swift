//
//  Settings.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/5/2023.
//

import Foundation

struct Settings {
    var clockMultiplier = 1.0
    
    var useExtendedResolution = false
    
    var renderTiles = true
    var renderWindow = true
    var renderSprites = true
    
    var colourPalette: ColourPalette = .blackAndWhite
    
    var isMuted = false
    var isChannel1Enabled = true
    var isChannel2Enabled = true
    var isChannel3Enabled = true
    var isChannel4Enabled = true
}
