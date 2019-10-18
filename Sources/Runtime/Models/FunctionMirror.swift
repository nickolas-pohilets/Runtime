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

            var offset = md.offsetToFirstCapture
            offset += MemoryLayout<Any.Type>.size * md.numBindings

            let bindingsPtr = ctx.raw.advanced(by: md.offsetToFirstCapture).assumingMemoryBound(to: Any.Type.self)
            let bindings = UnsafeBufferPointer(start: bindingsPtr, count: Int(md.numBindings))
            let metadataSources = try md.metadataSources()
            let types = md.capturedTypes()
            values = try FunctionMirror.buildValues(
                ctx: ctx,
                offset: offset,
                bindings: bindings,
                metadataSources: metadataSources,
                types: types
            )
        }

        self.function = funcPtr!
        self.context = ctxPtr
        self.capturedValues = values
    }

    static func buildValues(
        ctx: UnsafeRawPointer,
        offset: Int,
        bindings: UnsafeBufferPointer<Any.Type>,
        metadataSources: [(GenericParam, MetadataSource)],
        types: [MangledTypeName]
    ) throws -> [Any] {
        let levelsCount = metadataSources.map { $0.0.depth }.max().map { $0 + 1} ?? 0
        var counts = Array<Int>(repeating: 0, count: levelsCount)
        for (param, _) in metadataSources {
            counts[param.depth] = max(counts[param.depth], param.index + 1)
        }
        var indices: [GenericParam: Int] = [:]
        var totalCount = 0
        for (i, x) in counts.enumerated() {
            for j in 0..<x {
                indices[GenericParam(depth: i, index: j)] = indices.count
            }
            totalCount += x
            counts[i] = totalCount
        }

        let requirementsCount = 0;

        // See TargetGenericEnvironment<> and IRGenModule::getAddrOfGenericEnvironment()
        // Layout of the environment data structure:
        // - flags: 32 bit
        //    - number of levels: 12 bit
        //    - number of requirements: 12 bit
        //    - reserved: 8 bit
        // - running counts of generic params per level
        //    - number of levels x 16 bit
        // - generic params
        //    - total number of params x 8 bit
        //       - kind: 6 bit
        //          - 0 = type
        //          - other - reserved
        //      - hasExtraArgument: 1 bit - always false
        //      - hasKeyArgument: 1 bit - true if generic parameter cannot deduced from same type requirements - see GenericSignatureImpl::forEachParam()
        // - generic requirements
        //    - number of requirements x 64 bit
        //       - flags: 32 bit
        //          - kind: 6 bit
        //             - 0 = protocol requirement
        //             - 1 = same-type requirement
        //             - 2 = base class requirement
        //             - 3 = same conformance
        //             - 0x1F = a layout constraint
        //          - hasExtraArgument: 1 bit
        //          - hasKeyArgument: 1 bit
        //       - relative offset to param: 16 bit
        //       - kind-specific payload: 16 bit
        let envSize = 4 + 2 * levelsCount + 1 * totalCount + 8 * requirementsCount;
        let envPtr = UnsafeMutableRawPointer.allocate(byteCount: envSize, alignment: 16)
        defer { envPtr.deallocate() }

        var ptr = envPtr
        ptr.assumingMemoryBound(to: UInt32.self).pointee = UInt32(levelsCount) | (UInt32(requirementsCount) << 12)
        ptr = ptr.advanced(by: 4)

        for k in counts {
            ptr.assumingMemoryBound(to: UInt16.self).pointee = UInt16(k)
            ptr = ptr.advanced(by: 2)
        }

        for _ in 0..<totalCount {
            ptr.assumingMemoryBound(to: UInt8.self).pointee = 0x80
            ptr = ptr.advanced(by: 1)
        }

        let argsPtr = UnsafeMutablePointer<Any.Type?>.allocate(capacity: totalCount)
        defer { argsPtr.deallocate() }
        for i in 0..<totalCount {
            argsPtr.advanced(by: i).initialize(to: nil)
        }

        var captureIndicesAffectingMetadata = Set<Int>()
        for (param, source) in metadataSources {
            if let captureIndex = source.captureIndex {
                captureIndicesAffectingMetadata.insert(captureIndex)
            }
            let md = source.resolve(bindings: bindings, values: [])
            let index = indices[param]!
            argsPtr.advanced(by: index).pointee = md
        }

        var values: [Any] = []
        var fieldOffset = offset
        for (i, mangledType) in types.enumerated() {
            let type = try mangledType.type(genericEnvironment: envPtr, genericArguments: argsPtr)
            var effectiveType = type
            if Kind(type: type) == .opaque {
                effectiveType = ByRefMirror.self
            }
            let info = try metadata(of: effectiveType)
            let alignedOffset = (fieldOffset + info.alignment - 1) & ~(info.alignment - 1)
            fieldOffset = alignedOffset + info.size

            let fieldPtr = ctx.advanced(by: alignedOffset)
            let getter = getters(type: effectiveType)
            let value = getter.get(from: fieldPtr)
            values.append(value)

            if captureIndicesAffectingMetadata.contains(i) {
                for (param, source) in metadataSources {
                   let md = source.resolve(bindings: bindings, values: values)
                   let index = indices[param]!
                   argsPtr.advanced(by: index).pointee = md
               }
            }
        }
        return values
    }
}
