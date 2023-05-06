//
//  GameBoy.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 6/5/2023.
//

import Foundation

class GameBoy {
    
    static let instance = GameBoy()
    private init () {}
    
    var cartridge: Cartridge?
    
    private(set) var clock = MasterClock()
    private(set) var mmu = MMU()
    private(set) var cpu = CPU()
    private(set) var ppu = PPU()
    private(set) var apu = APU()
    private(set) var joypad = Joypad()
    
    weak var screenRenderDelegate: ScreenRenderDelegate?
    
    func loadCartridge(romURL: URL, skipBootROM: Bool) throws {
        resetState()
        cartridge = try Cartridge(romURL: romURL)
        
        if skipBootROM {
            mmu.skipBootRom()
            cpu.skipBootRom()
        }
    }
    
    func removeCartridge() {
        resetState()
        cartridge = nil
    }
    
    private func resetState() {
        clock.stopTicking()
        
        clock = MasterClock()
        mmu = MMU()
        cpu = CPU()
        ppu = PPU()
        apu = APU()
        joypad = Joypad()
    }
    
    func saveDataToFile() {
        guard let cartridge else { return }
        
        let saveDataURL = cartridge.saveDataURL
        let saveData = cartridge.getRAMSnapshot()
        
        if (FileManager.default.createFile(atPath: saveDataURL.path, contents: saveData, attributes: nil)) {
            print("File created successfully.")
        } else {
            print("File not created.")
        }
    }
    
    func renderScreen() {
        screenRenderDelegate?.renderScreen(screenData: ppu.screenData)
    }
}

protocol ScreenRenderDelegate: AnyObject {
    func renderScreen(screenData: [ColourPalette.PixelData])
}
