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
    
    var debugProperties = DebugProperties()
    weak var screenRenderDelegate: ScreenRenderDelegate?
    
    private var periodicSaveTimer: Timer?
    private static let saveIntervalSeconds: TimeInterval = 5
    
    func loadCartridge(romURL: URL, skipBootROM: Bool) throws {
        resetState()
        cartridge = try Cartridge(romURL: romURL)
        
        if skipBootROM {
            mmu.skipBootRom()
            cpu.skipBootRom()
        }
        
        setupPeriodicSaving()
    }
    
    func removeCartridge() {
        periodicSaveTimer?.invalidate()
        periodicSaveTimer = nil
        
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
    
    private func setupPeriodicSaving() {
        periodicSaveTimer = .scheduledTimer(
            withTimeInterval: Self.saveIntervalSeconds,
            repeats: true
        ) { _ in
            self.saveDataToFile()
        }
    }
    
    func saveDataToFile() {
        guard let cartridge else { return }
        
        let saveDataURL = cartridge.saveDataURL
        let saveData = cartridge.getRAMSnapshot()
        
        let saveWasSuccessful = FileManager.default.createFile(atPath: saveDataURL.path, contents: saveData, attributes: nil)
        if !saveWasSuccessful {
            print("Failed to save file.")
        }
    }
    
    func renderScreen() {
        screenRenderDelegate?.renderScreen(screenData: ppu.screenData, isExtendedResolution: debugProperties.useExtendedResolution)
    }
}

// MARK: - Static Constants

extension GameBoy {
    // Resolution
    static let pixelWidth = 160
    static let pixelHeight = 144
    
    static let extendedPixelWidth = 255
    static let extendedPixelHeight = 255
}

// MARK: - ScreenRenderDelegate

protocol ScreenRenderDelegate: AnyObject {
    func renderScreen(screenData: [ColourPalette.PixelData], isExtendedResolution: Bool)
}
