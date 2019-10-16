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

public struct ByRefMirror: Hashable {
    // TODO: Ideally this should be Builtin.NativeObject to have proper reference counting
    // Note that this cannot be AnyObject, which also does some ObjC checks and crashes there.
    private var ptr: UnsafeRawPointer

    public func type() throws -> Any.Type {
        return try self.field().1
    }

    public func value() throws -> Any {
        let (ptr, type) = try self.field()
        return getters(type: type).get(from: ptr)
    }

    public func setValue(_ value: Any) throws {
        let (ptr, type) = try self.field()
        setters(type: type).set(value: value, pointer: UnsafeMutableRawPointer(mutating: ptr))
    }

    private func field() throws -> (UnsafeRawPointer, Any.Type) {
        let type = self.ptr.assumingMemoryBound(to: HeapObject.self).pointee.md
        switch Kind(type: type) {
        case .heapLocalVariable:
            let md = HeapLocalVariableMetadata(type: type)
            let fields = try md.fields()
            if fields.count != 1 {
                throw RuntimeError.unexpectedByRefLayout(type: md.type)
            }
            let (offset, fieldType) = fields[0]
            let ptr = self.ptr.advanced(by: offset)
            return (ptr, fieldType)
        case .heapGenericLocalVariable:
            let md = HeapGenericLocalVariableMetadata(type: type)
            let ptr = self.ptr.advanced(by: md.valueOffset)
            return (ptr, md.valueType)
        default:
            throw RuntimeError.unexpectedByRefLayout(type: type)
        }
    }
}

private struct HeapObject {
    var md: Any.Type
}

private struct SwiftFunction {
    var f: @convention(c) (AnyObject) -> Void
    var ctx: UnsafePointer<HeapObject>?
}

public struct FunctionMirror {
    public var info: FunctionInfo
    public var function: UnsafeRawPointer
    public var context: UnsafeRawPointer?
    public var capturedValues: [Any]

    public init(reflecting f: Any) throws {
        self.info = try functionInfo(of: f)
        if info.callingConvention != .swift {
            throw RuntimeError.unsupportedCallingConvention(function: f, callingConvention: info.callingConvention)
        }
        
        var ff = f

        var funcPtr = UnsafeRawPointer(bitPattern: 0)
        var ctxPtr = UnsafeRawPointer(bitPattern: 0)
        var values: [Any] = []

        try withValuePointer(of: &ff) {
            let f = $0.assumingMemoryBound(to: SwiftFunction.self).pointee

            funcPtr = unsafeBitCast(f.f, to: UnsafeRawPointer.self)

            guard let ctx = f.ctx else { return }
            ctxPtr = ctx.raw
            let type = ctx.pointee.md
            let kind = Kind(type: type)
            assert(kind == .heapLocalVariable)
            let md = HeapLocalVariableMetadata(type: type)

            for (offset, type) in try md.fields() {
                let fieldPtr = ctx.raw.advanced(by: offset)
                let getter = getters(type: type)
                let value = getter.get(from: fieldPtr)
                values.append(value)
            }
        }

        self.function = funcPtr!
        self.context = ctxPtr
        self.capturedValues = values
    }
}
