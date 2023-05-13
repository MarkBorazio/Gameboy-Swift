//
//  FileMenu.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 13/5/2023.
//

import Cocoa

class FileMenu: NSMenu {
    
    init() {
        super.init(title: "File")
        
        let openRomItem = CommonMenuItem(title: "Open ROM") {
            Coordinator.instance.presentFileSelector()
        }
        
        let openSavesFolderItem = CommonMenuItem(title: "Open Saves Folder") {
            do {
                let url = try GameBoy.getSavesFolderURL()
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                Coordinator.instance.presentWarningModal(title: "Failed to open saves folder.", message: nil)
            }
        }
        
        items = [
            openRomItem,
            openSavesFolderItem
        ]
    }
    
    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
