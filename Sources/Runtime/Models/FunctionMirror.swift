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

struct HeapObject {
    var md: Any.Type
}

struct SwiftFunction {
    var f: @convention(c) (AnyObject) -> Void
    var ctx: UnsafePointer<HeapObject>?
}

// For some reason when packing function into Any, it wraps function into another function
// Once we can see that this another function captures a function, recursive comparison should handle this
// But for now, hardcode this indirection
struct SwiftFunctionWrapperContext {
    var md: Any.Type
    var rc: Int
    var f: SwiftFunction
}

struct SwiftFunctionWrapper {
    var f: @convention(c) (AnyObject) -> Void
    var ctx: UnsafePointer<SwiftFunctionWrapperContext>
}

public struct FunctionMirror {
    public var info: FunctionInfo
    public var function: UnsafeRawPointer
    public var capturedValues: [Any]

    public init(reflecting f: Any) throws {
        self.info = try functionInfo(of: f)
        if info.callingConvention != .swift {
            throw RuntimeError.unsupportedCallingConvention(function: f, callingConvention: info.callingConvention)
        }
        
        var ff = f

        var funcPtr = UnsafeRawPointer(bitPattern: 0)
        var values: [Any] = []

        try withValuePointer(of: &ff) {
            let ptr = $0.assumingMemoryBound(to: SwiftFunctionWrapper.self)
            let f = ptr.pointee.ctx.pointee.f

            funcPtr = unsafeBitCast(f.f, to: UnsafeRawPointer.self)

            guard let ctx = f.ctx else { return }
            let type = ctx.pointee.md
            let kind = Kind(type: type)
            assert(kind == .heapLocalVariable)
            let md = HeapLocalVariableMetadata(type: type)
            var offset = Int(md.offsetToFirstCapture)
            for type in md.types {
                let info = try metadata(of: type)
                let getter = getters(type: type)

                offset = (offset + info.alignment - 1) & ~(info.alignment - 1)
                let fieldPtr = ctx.raw.advanced(by: offset)
                let value = getter.get(from: fieldPtr)
                values.append(value)
                offset += info.size
            }
        }

        self.function = funcPtr!
        self.capturedValues = values
    }
}
