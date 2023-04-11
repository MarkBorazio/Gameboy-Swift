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
    
    // TODO: Maybe just override the read; that way, we don't need to write all of the time.
    // Also override the writes so that we keep track of the selection as well
    // What is in the memoryMap won't matter at that point.
    func updateJoypadByte(_ newByte: UInt8) {
    
        var newJoypadByte = newByte | 0x0F // Set bottom 4 bits high as that means they not held down
        
        let isDirectionSelected = !newJoypadByte.checkBit(MMU.selectDirectionButtonsBitIndex)
        let isActionSelected = !newJoypadByte.checkBit(MMU.selectActionButtonsBitIndex)
        
        if isDirectionSelected {
            let heldDirectionButtons = buttonsHeldDown.filter { $0.selectionBitIndex == MMU.selectDirectionButtonsBitIndex }
            heldDirectionButtons.forEach {
                newJoypadByte.clearBit($0.bitIndex)
            }
        }
        
        if isActionSelected {
            let heldDirectionButtons = buttonsHeldDown.filter { $0.selectionBitIndex == MMU.selectActionButtonsBitIndex }
            heldDirectionButtons.forEach {
                newJoypadByte.clearBit($0.bitIndex)
            }
        }
        
        MMU.shared.memoryMap[MMU.addressJoypad] = newJoypadByte
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
            case .down, .start: return MMU.joypadDownOrStartBitIndex
            case .up, .select: return MMU.joypadUpOrSelectBitIndex
            case .left, .b: return MMU.joypadLeftOrBBitIndex
            case .right, .a: return MMU.joypadRightOrABitIndex
            }
        }
        
        var selectionBitIndex: Int {
            switch self {
            case .a, .b, .start, .select: return MMU.selectActionButtonsBitIndex
            case .up, .down, .left, .right: return MMU.selectDirectionButtonsBitIndex
            }
        }
    }
}

extension Joypad: JoypadDelegate {
    
    func buttonDown(_ button: Button) {
        buttonsHeldDown.insert(button)
        
        var joypadByte = MMU.shared.readValue(address: MMU.addressJoypad)
        let isButtonTypeSelected = !joypadByte.checkBit(button.selectionBitIndex) // 0 means selected, 1 means unselected
        guard isButtonTypeSelected else { return }

        joypadByte.clearBit(button.bitIndex)
        MMU.shared.writeValue(joypadByte, address: MMU.addressJoypad)
        MMU.shared.requestJoypadInterrupt()
    }
    
    func buttonUp(_ button: Button) {
        buttonsHeldDown.remove(button)
        
        var joypadByte = MMU.shared.readValue(address: MMU.addressJoypad)
        let isButtonTypeSelected = !joypadByte.checkBit(button.selectionBitIndex) // 0 means selected, 1 means unselected
        guard isButtonTypeSelected else { return }
        
        joypadByte.setBit(button.bitIndex)
        MMU.shared.writeValue(joypadByte, address: MMU.addressJoypad)
    }
}
