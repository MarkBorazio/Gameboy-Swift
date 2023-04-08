//
//  ByteConvertible.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 14/8/21.
//

import Foundation

extension BinaryInteger {
    
    static var byteWidth: Int { MemoryLayout<Self>.size }
    
    public init?(bytes: [UInt8], endianness: Endianness = .littleEndian) {
        guard bytes.count <= Self.byteWidth else { return nil }

        let adjustedBytes = endianness.matchesPlatform ? bytes : bytes.reversed()
        let data = Data(adjustedBytes)

        let optionalValue = data.withUnsafeBytes {
            $0.baseAddress?.assumingMemoryBound(to: Self.self).pointee
        }
        guard let value = optionalValue else { return nil }
        self = value
    }
    
    public func asBytes(endianness: Endianness = .littleEndian) -> [UInt8] {
        let width = Self.byteWidth
        var bytes = [UInt8](repeating: 0, count: width)

        withUnsafeBytes(of: self) { rawBufferPointer in
            for i in 0..<width {
                bytes[i] = rawBufferPointer[i]
            }
        }

        let adjustedBytes = endianness.matchesPlatform ? bytes : bytes.reversed()
        return adjustedBytes
    }
}

public enum Endianness {
    case bigEndian
    case littleEndian
    
    var matchesPlatform: Bool {
        switch self {
        case .bigEndian: return CFByteOrderGetCurrent() == CFByteOrder(CFByteOrderBigEndian.rawValue)
        case .littleEndian: return CFByteOrderGetCurrent() == CFByteOrder(CFByteOrderLittleEndian.rawValue)
        }
    }
}
