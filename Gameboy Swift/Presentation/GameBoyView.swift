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
    private static let size = NSSize(width: pixelWidth, height: pixelHeight)
    
    private let colourSpace = CGColorSpaceCreateDeviceRGB()
    private let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    var mutableColours: [NSColor] = Array(repeating: .clear, count: pixelWidth * pixelHeight)
    let context: CGContext
    
    override init(frame frameRect: NSRect) {
        context = CGContext(
            data: &mutableColours,
            width: Self.pixelWidth,
            height: Self.pixelHeight,
            bitsPerComponent: UInt8.bitWidth,
            bytesPerRow: Self.pixelWidth * MemoryLayout<NSColor>.stride,
            space: colourSpace,
            bitmapInfo: bitmapInfo.rawValue
        )!
        super.init(frame: frameRect)
    }
    
    required init?(coder: NSCoder) {
        context = CGContext(
            data: &mutableColours,
            width: Self.pixelWidth,
            height: Self.pixelHeight,
            bitsPerComponent: UInt8.bitWidth,
            bytesPerRow: Self.pixelWidth * MemoryLayout<NSColor>.stride,
            space: colourSpace,
            bitmapInfo: bitmapInfo.rawValue
        )!
        super.init(coder: coder)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.wantsLayer = true
        layer?.magnificationFilter = .nearest
    }
    
    private func constructImage(screenData: [ColourPalette.PixelData]) -> CGImage? {
        let colours = screenData.map(ColourPalette.getColour)
        var mutableColors = colours // make a mutable copy of the array
        let context = CGContext(
            data: &mutableColors,
            width: Self.pixelWidth,
            height: Self.pixelHeight,
            bitsPerComponent: UInt8.bitWidth,
            bytesPerRow: Self.pixelWidth * MemoryLayout<NSColor>.stride,
            space: colourSpace,
            bitmapInfo: bitmapInfo.rawValue
        )
        return context?.makeImage()
    }
}

// MARK: - ScreenRenderDelegate Implementation

extension GameBoyView: ScreenRenderDelegate {
    
    func renderScreen(screenData: [ColourPalette.PixelData]) {
        DispatchQueue.main.async { [unowned self] in
            mutableColours = screenData.map(ColourPalette.getColour)
            layer?.contents = context.makeImage()
        }
    }
}
