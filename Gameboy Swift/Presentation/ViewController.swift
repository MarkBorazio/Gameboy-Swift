//
//  ViewController.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet var gameBoyView: GameBoyView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set up the event monitor to detect key presses and releases
        view.window?.makeFirstResponder(view)
        
        NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) {
            if let window = $0.window, window.firstResponder == self.view {
                if $0.type == .keyDown {
                    self.keyDown(with: $0)
                } else if $0.type == .keyUp {
                    self.keyUp(with: $0)
                }
                return nil
            }
            return $0
        }
        
        MasterClock.shared.screenRenderDelegate = gameBoyView
    }
    
    override func mouseDown(with event: NSEvent) {
        // Make the view the first responder when it receives a mouse down event
        view.window?.makeFirstResponder(view)
    }

    override func keyDown(with event: NSEvent) {
        guard let button = getButtonFromEvent(event: event) else { return }
        Joypad.shared.buttonDown(button)
    }
    
    override func keyUp(with event: NSEvent) {
        guard let button = getButtonFromEvent(event: event) else { return }
        Joypad.shared.buttonUp(button)
    }
    
    private func getButtonFromEvent(event: NSEvent) -> Joypad.Button? {
        switch event.keyCode {
        case 6: return .a
        case 7: return .b
        case 36: return .start
        case 60: return .select
        case 123: return .left
        case 124: return .right
        case 125: return .down
        case 126: return .up
        default: return nil
        }
    }
}

