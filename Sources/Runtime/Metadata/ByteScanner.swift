// MIT License
//
// Copyright (c) 2019 Mykola Pokhylets
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation

struct ByteScanner {
    var slice: Slice<UnsafeBufferPointer<UInt8>>

    init(buffer: UnsafeBufferPointer<UInt8>) {
        self.slice = buffer[0...]
    }

    func atEnd() -> Bool {
        return slice.isEmpty
    }

    mutating func scan(scalar: UnicodeScalar) -> Bool {
        guard let byte = slice.first else { return false }
        if UInt32(byte) != scalar.value {
            return false
        }
        slice = slice.dropFirst()
        return true
    }

    mutating func scanScalar() -> UnicodeScalar? {
        guard let byte = slice.first else { return nil }
        let res = UnicodeScalar(UInt32(byte))
        slice = slice.dropFirst()
        return res
    }

    mutating func scanNatural() -> Int? {
        var value = 0
        var scannedAny = false
        var overflow = false
        let digit0 = UnicodeScalar("0").value
        let digit9 = UnicodeScalar("9").value
        while let byte = slice.first, byte >= digit0, byte <= digit9 {
            scannedAny = true
            let digit = Int(UInt32(byte) - digit0)
            slice = slice.dropFirst()
            if value > (Int.max - digit) / 10 {
                overflow = true
            } else {
                value = value * 10 + digit
            }
        }
        return (scannedAny && !overflow) ? value : nil
    }
}
