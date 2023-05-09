//
//  GameBoyView.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 2/4/2023.
//

import Cocoa

class GameBoyView: NSView {
    
    private let colourSpace = CGColorSpaceCreateDeviceRGB()
    private let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    
    lazy var aspectRatioConstraint = widthAnchor.constraint(equalTo: heightAnchor, multiplier: CGFloat(GameBoy.pixelWidth)/CGFloat(GameBoy.pixelHeight))
    lazy var extendedAspectRatioConstraint = widthAnchor.constraint(equalTo: heightAnchor, multiplier: CGFloat(GameBoy.extendedPixelWidth)/CGFloat(GameBoy.extendedPixelHeight))
    
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
        
        let heightConstraint = heightAnchor.constraint(greaterThanOrEqualToConstant: 500)
        let widthConstraint = widthAnchor.constraint(greaterThanOrEqualToConstant: 500)
            
        NSLayoutConstraint.activate([
            heightConstraint,
            widthConstraint,
            aspectRatioConstraint
        ])
    }
}

// MARK: - ScreenRenderDelegate Implementation

extension GameBoyView: ScreenRenderDelegate {
    
    func renderScreen(screenData: [ColourPalette.PixelData], isExtendedResolution: Bool) {
        let width = isExtendedResolution ? GameBoy.extendedPixelWidth : GameBoy.pixelWidth
        let height = isExtendedResolution ? GameBoy.extendedPixelHeight : GameBoy.pixelHeight
        
        aspectRatioConstraint.isActive = !isExtendedResolution
        extendedAspectRatioConstraint.isActive = isExtendedResolution
        
        DispatchQueue.main.async { [unowned self] in
            var mutableColours = screenData.map(ColourPalette.getColour)
            let someContext = CGContext(
                data: &mutableColours,
                width: width,
                height: height,
                bitsPerComponent: UInt8.bitWidth,
                bytesPerRow: width * MemoryLayout<UInt32>.size,
                space: colourSpace,
                bitmapInfo: bitmapInfo.rawValue
            )!
            layer?.contents = someContext.makeImage()
        }
    }
}
