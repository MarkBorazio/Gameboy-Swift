//
//  DebugProperties.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/5/2023.
//

import Foundation

struct DebugProperties {
    var clockMultiplier = 1.0
    
    var useExtendedResolution = false
    
    var renderTiles = true
    var renderWindow = true
    var renderSprites = true
    
    var colour1: UInt32? = nil
    var colour2: UInt32? = nil
    var colour3: UInt32? = nil
    var colour4: UInt32? = nil
    
    var isMuted = false
    var isChannel1Enabled = true
    var isChannel2Enabled = true
    var isChannel3Enabled = true
    var isChannel4Enabled = true
}
