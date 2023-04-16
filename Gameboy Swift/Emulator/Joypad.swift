//
//  Joypad.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 11/4/2023.
//

import Foundation

protocol JoypadDelegate: AnyObject {
    func buttonDown(_ button: Joypad.Button)
    func buttonUp(_ button: Joypad.Button)
}

class Joypad {
    
    static let shared = Joypad()
    
    // Source of truth for if a button is held down or not
    private var buttonsHeldDown: Set<Button> = []
    
    func readJoypad() -> UInt8 {
        var newJoypadByte = MMU.shared.memoryMap[Memory.addressJoypad] | 0x0F // Set bottom 4 bits high as that means they not held down
        
        let isDirectionSelected = !newJoypadByte.checkBit(Memory.selectDirectionButtonsBitIndex)
        let isActionSelected = !newJoypadByte.checkBit(Memory.selectActionButtonsBitIndex)
        
        let buttonsHeldDown = buttonsHeldDown // Create copy to avoid reading during a write
        if isDirectionSelected {
            let heldDirectionButtons = buttonsHeldDown.filter { $0.selectionBitIndex == Memory.selectDirectionButtonsBitIndex }
            heldDirectionButtons.forEach {
                newJoypadByte.clearBit($0.bitIndex)
            }
        }
        
        if isActionSelected {
            let heldDirectionButtons = buttonsHeldDown.filter { $0.selectionBitIndex == Memory.selectActionButtonsBitIndex }
            heldDirectionButtons.forEach {
                newJoypadByte.clearBit($0.bitIndex)
            }
        }
        
        return newJoypadByte
    }
    
    enum Button: Equatable {
        case a
        case b
        case start
        case select
        case up
        case down
        case right
        case left
        
        var bitIndex: Int {
            switch self {
            case .down, .start: return Memory.joypadDownOrStartBitIndex
            case .up, .select: return Memory.joypadUpOrSelectBitIndex
            case .left, .b: return Memory.joypadLeftOrBBitIndex
            case .right, .a: return Memory.joypadRightOrABitIndex
            }
        }
        
        var selectionBitIndex: Int {
            switch self {
            case .a, .b, .start, .select: return Memory.selectActionButtonsBitIndex
            case .up, .down, .left, .right: return Memory.selectDirectionButtonsBitIndex
            }
        }
    }
}

extension Joypad: JoypadDelegate {
    
    func buttonDown(_ button: Button) {
        buttonsHeldDown.insert(button)
        
        let joypadByte = MMU.shared.readValue(address: Memory.addressJoypad)
        let isButtonTypeSelected = !joypadByte.checkBit(button.selectionBitIndex) // 0 means selected, 1 means unselected
        if isButtonTypeSelected {
            MMU.shared.requestJoypadInterrupt()
        }
    }
    
    func buttonUp(_ button: Button) {
        buttonsHeldDown.remove(button)
    }
}
