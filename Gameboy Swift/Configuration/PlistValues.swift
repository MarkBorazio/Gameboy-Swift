//
//  PlistValues.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 13/5/2023.
//

import Foundation

enum PlistValues {
    static let appName = Bundle.main.infoDictionary!["CFBundleName"] as! String
}
