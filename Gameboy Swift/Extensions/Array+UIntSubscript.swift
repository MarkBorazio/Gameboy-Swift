//
//  Array+UIntSubscript.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/8/21.
//

import Foundation

extension Array {

    subscript<T: UnsignedInteger>(index: T) -> Element {
        get {
            self[Int(index)]
        }
        set {
            self[Int(index)] = newValue
        }
    }
}
