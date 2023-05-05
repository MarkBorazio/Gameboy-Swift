//
//  GameBoyView.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 2/4/2023.
//

import Cocoa

class GameBoyView: NSView {
    
    private static let pixelWidth = 160
    private static let pixelHeight = 144
    private let colourSpace = CGColorSpaceCreateDeviceRGB()
    private let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        initialise()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        initialise()
    }
    
    private func initialise() {
        self.wantsLayer = true
        layer?.magnificationFilter = .nearest
    }
}

// MARK: - ScreenRenderDelegate Implementation

extension GameBoyView: ScreenRenderDelegate {
    
    func renderScreen(screenData: [ColourPalette.PixelData]) {
        DispatchQueue.main.async { [unowned self] in
            var mutableColours = screenData.map(ColourPalette.getColour)
            let someContext = CGContext(
                data: &mutableColours,
                width: Self.pixelWidth,
                height: Self.pixelHeight,
                bitsPerComponent: UInt8.bitWidth,
                bytesPerRow: Self.pixelWidth * MemoryLayout<UInt32>.size,
                space: colourSpace,
                bitmapInfo: bitmapInfo.rawValue
            )!
            layer?.contents = someContext.makeImage()
        }
    }
}
