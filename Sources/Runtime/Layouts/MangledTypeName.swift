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

struct MangledTypeName: CustomStringConvertible {
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
                end += MemoryLayout<UnsafeRawPointer>.size
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

    func type(genericEnvironment: UnsafeRawPointer?, genericArguments: UnsafeRawPointer?) -> Any.Type {
        let buf = self.buffer
        if buf.count == 2 && buf[0] == 66 && buf[1] == 112 { // "Bp"
            return UnsafeRawPointer.self
        }
        let metadataPtr = swift_getTypeByMangledNameInEnvironment(
            self.base.raw.assumingMemoryBound(to: Int8.self),
            self.length,
            genericEnvironment,
            genericArguments?.assumingMemoryBound(to: Optional<UnsafeRawPointer>.self)
        )!
        return unsafeBitCast(metadataPtr, to: Any.Type.self)
    }

    var description: String {
        var res = ""

        var end = base
        while let current = Optional(end.pointee), current != 0 {
            end += 1
            if current >= 0x1 && current <= 0x1F {
                let ptr: UnsafeRawPointer
                if current < 0x18 {
                    // Relative reference
                    let offset = end.raw.assumingMemoryBound(to: Int32.self).pointee
                    ptr = end.raw.advanced(by: Int(offset))
                    end += 4
                } else {
                    // Absolute reference reference
                    ptr = end.raw.assumingMemoryBound(to: UnsafeRawPointer.self).pointee
                    end += MemoryLayout<UnsafeRawPointer>.size
                }
                let kind = String(format: "%02x", current)
                res += "{\(kind):\(ptr)}"
            } else {
                res.unicodeScalars.append(UnicodeScalar(current))
            }
        }
        return res
    }
}
