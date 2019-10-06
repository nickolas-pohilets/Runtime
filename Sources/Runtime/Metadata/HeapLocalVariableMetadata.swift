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

struct HeapLocalVariableMetadata {
    var pointer: UnsafeMutablePointer<HeapLocalVariableMetadataLayout>
    init(type: Any.Type) {
        self.pointer = unsafeBitCast(type, to: UnsafeMutablePointer<HeapLocalVariableMetadataLayout>.self)
    }
    
    var type: Any.Type {
        return unsafeBitCast(pointer, to: Any.Type.self)
    }
    
    var kind: Kind {
        return Kind(flag: pointer.pointee._kind)
    }

    var offsetToFirstCapture: UInt32 {
        return pointer.pointee.offsetToFirstCapture
    }

    private var _mangedTypeNames: [UnsafeMutablePointer<CChar>] {
        var buffer = self.pointer.pointee.captureDescription.pointee.captureTypeRecordBuffer()
        var res: [UnsafeMutablePointer<CChar>] = []
        while !buffer.isEmpty {
            let ptr = buffer.baseAddress!.pointee.mangledTypeName.advanced()
            res.append(ptr)
            buffer = UnsafeMutableBufferPointer(rebasing: buffer.dropFirst())
        }
        return res
    }
    
    var typeNames: [String] {
        return _mangedTypeNames.map { String(utf8String: $0)! }
    }

    var types:[Any.Type] {
        return _mangedTypeNames.map {
            let metadataPtr = swift_getTypeByMangledNameInContext(
                $0,
                getSymbolicMangledNameLength($0),
                nil,
                nil
            )!
            return unsafeBitCast(metadataPtr, to: Any.Type.self)
        }
    }

    private func getSymbolicMangledNameLength(_ base: UnsafeRawPointer) -> Int32 {
        var end = base
        while let current = Optional(end.load(as: UInt8.self)), current != 0 {
            end += 1
            if current >= 0x1 && current <= 0x17 {
                end += 4
            } else if current >= 0x18 && current <= 0x1F {
                end += MemoryLayout<Int>.size
            }
        }

        return Int32(end - base)
    }
}
