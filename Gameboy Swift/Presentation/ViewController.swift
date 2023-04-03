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

        MasterClock.shared.screenRenderDelegate = gameBoyView
        // Do any additional setup after loading the view.
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}

