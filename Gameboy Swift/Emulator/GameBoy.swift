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
    
    private var screenRenderRequested = false // Has clock requested screen render?
    private var screenRenderReady = false // Had PPU signalled that screen is ready to render?
    weak var screenRenderDelegate: ScreenRenderDelegate?
    
    private var periodicSaveTimer: Timer?
    
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
}

// MARK: - Screen Render Synchronisation

// Since the clock is synchronised by audio, our video requires extra logic to
// to make sure that we only render the frame once it is ready. Otherwise, we run
// into bad screen tearing.
extension GameBoy {
    
    func notifyScreenRenderNotReady() {
        screenRenderReady = false
    }
    
    func notifyScreenRenderReady() {
        if screenRenderRequested {
            renderScreen()
        } else {
            screenRenderReady = true
        }
    }
    
    func requestScreenRender() {
        if screenRenderReady {
            renderScreen()
        } else {
            screenRenderRequested = true
        }
    }
    
    private func renderScreen() {
        screenRenderDelegate?.renderScreen(screenData: ppu.screenData, isExtendedResolution: debugProperties.useExtendedResolution)
        screenRenderRequested = false
        screenRenderReady = false
    }
}

// MARK: - Static Constants and Methods

extension GameBoy {
    
    private static let saveIntervalSeconds: TimeInterval = 5
    
    // Standard Resolution
    static let pixelWidth = 160
    static let pixelHeight = 144
    
    // Extended Resolution
    static let extendedPixelWidth = 256
    static let extendedPixelHeight = 256
    
    static func getSavesFolderURL() throws -> URL {
        try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
}

// MARK: - ScreenRenderDelegate

protocol ScreenRenderDelegate: AnyObject {
    func renderScreen(screenData: [ColourPalette.PixelData], isExtendedResolution: Bool)
}
