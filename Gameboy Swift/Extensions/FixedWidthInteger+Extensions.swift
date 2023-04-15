//
//  FixedWidthInteger+Extensions.swift
//  Gameboy Swift
//
//  Created by Mark Borazio [Personal] on 8/4/2023.
//

import Foundation

extension FixedWidthInteger {
    
    /// Returns the minimum number of bits required to represent the number.
    /// This is simply the total bit width minus the leading zero bit count.
    ///
    /// ```
    /// let value = 0b0001_0010
    /// print(value.minimumBitWidth) // 5
    /// ```
    var minimumBitWidth: Int {
        return bitWidth - leadingZeroBitCount
    }
    
    /// Chains together multiple `addingReportingOverflow` calls to detect if there was an overflow at least once
    /// over the multiple additions.
    func addingMultipleReportingOverflow(_ others: Self...) -> (partialValue: Self, overflow: Bool) {
        var didOverflow = false
        var totalValue = self
        
        for value in others {
            let (newTotalValue, overflow) = totalValue.addingReportingOverflow(value)
            totalValue = newTotalValue
            didOverflow = didOverflow || overflow
        }
        
        return (totalValue, didOverflow)
    }
    
    /// Chains together multiple `subtractingReportingOverflow` calls to detect if there was an overflow at least once
    /// over the multiple additions.
    func subtractingMultipleReportingOverflow(_ others: Self...) -> (partialValue: Self, overflow: Bool) {
        var didOverflow = false
        var totalValue = self
        
        for value in others {
            let (newTotalValue, overflow) = totalValue.subtractingReportingOverflow(value)
            totalValue = newTotalValue
            didOverflow = didOverflow || overflow
        }
        
        return (totalValue, didOverflow)
    }
}
