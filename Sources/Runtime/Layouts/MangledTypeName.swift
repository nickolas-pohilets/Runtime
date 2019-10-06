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
import CRuntime

struct MangledTypeName {
    var base: UnsafePointer<UInt8>
    var length: Int32

    init(_ base: UnsafeRawPointer) {
        self.base = base.assumingMemoryBound(to: UInt8.self)

        var end = base
        while let current = Optional(end.load(as: UInt8.self)), current != 0 {
            end += 1
            if current >= 0x1 && current <= 0x17 {
                end += 4
            } else if current >= 0x18 && current <= 0x1F {
                end += MemoryLayout<Int>.size
            }
        }

        self.length = Int32(end - base)
    }

    public var buffer: UnsafeBufferPointer<UInt8> {
        return UnsafeBufferPointer<UInt8>(start: self.base, count: Int(self.length))
    }

    func type(genericContext: UnsafeRawPointer?, genericArguments: UnsafeRawPointer?) -> Any.Type {
        let buf = self.buffer
        if buf.count == 2 && buf[0] == 66 && buf[1] == 112 { // "Bp"
            return UnsafeRawPointer.self
        }
        let metadataPtr = swift_getTypeByMangledNameInContext(
            self.base.raw.assumingMemoryBound(to: Int8.self),
            self.length,
            genericContext,
            genericArguments?.assumingMemoryBound(to: Optional<UnsafeRawPointer>.self)
        )!
        return unsafeBitCast(metadataPtr, to: Any.Type.self)
    }
}
