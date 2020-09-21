//
//  TestUtils.swift
//  SSKRTests
//
//  Created by Wolf McNally on 9/19/20.
//

import Foundation

extension Collection where Element == UInt8 {
    var hex: String { self.map { String(format: "%02hhx", $0) }.joined() }
}

extension UInt32 {
    var data: Data {
        let size = MemoryLayout<UInt32>.size
        var d = Data()
        d.reserveCapacity(size)
        for i in 0 ..< size {
            let o = (8 * (3 - i))
            let n = self >> o
            let c = UInt8(truncatingIfNeeded: n)
            d.append(c)
        }
        return d
    }

    var hex: String { data.hex }
}

extension String {
    var utf8: Data {
        return data(using: .utf8)!
    }

    var hexData: Data {
        let len = count / 2
        var data = Data(capacity: len)
        for i in 0..<len {
            let j = index(startIndex, offsetBy: i*2)
            let k = index(j, offsetBy: 2)
            let bytes = self[j..<k]
            if var num = UInt8(bytes, radix: 16) {
                data.append(&num, count: 1)
            } else {
                fatalError()
            }
        }
        return data
    }
}
