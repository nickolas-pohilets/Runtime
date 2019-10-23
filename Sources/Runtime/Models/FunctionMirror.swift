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

public enum HashableSupport {
    case none
    case witnessTable(UnsafeRawPointer)
    case reference
    case function
    case any
}

public enum CaptureTypeInfo {
    case direct(type: Any.Type, hashable: HashableSupport)
    case indirect(layout: CaptureLayout)
}

public struct CaptureReference: Hashable {
    var pointer: UnsafeRawPointer
    var type: Any.Type

    var value: Any {
        get {
            return getters(type: self.type).get(from: self.pointer)
        }
        nonmutating set {
            let mutablePtr = UnsafeMutableRawPointer(mutating: self.pointer)
            setters(type: self.type).set(value: newValue, pointer: mutablePtr)
        }
    }

    public static func == (lhs: CaptureReference, rhs: CaptureReference) -> Bool {
        return lhs.pointer == rhs.pointer && metadataPointer(type: lhs.type) == metadataPointer(type: rhs.type)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.pointer)
    }
}

public struct CaptureField {
    var offset: Int
    var typeInfo: CaptureTypeInfo

    var isHashable: Bool {
        switch typeInfo {
        case let .direct(_, hashable):
            switch hashable {
            case .none:
                return false
            default:
                return true
            }
        case let .indirect(layout):
            return layout.isHashable
        }
    }

    func enumerateReference(ctx: UnsafeRawPointer, block: (CaptureReference) throws -> Void ) rethrows {
        let ptr = ctx.advanced(by: offset)
        switch typeInfo {
        case let .direct(type, _):
            try block(CaptureReference(pointer: ptr, type: type))
        case let .indirect(layout):
            let indirectCtx = ptr.assumingMemoryBound(to: UnsafeRawPointer.self).pointee
            try layout.enumerateReference(ctx: indirectCtx, block: block)
        }
    }

    func areEqual(_ lhs: UnsafeRawPointer, _ rhs: UnsafeRawPointer) -> Bool {
        let lhsPtr = lhs.advanced(by: offset)
        let rhsPtr = rhs.advanced(by: offset)
        switch typeInfo {
        case let .direct(type, hashable):
            switch hashable {
            case .none:
                return false
            case .any:
                guard let lhsValue = asHashable(lhsPtr.assumingMemoryBound(to: Any.self).pointee) else { return false }
                guard let rhsValue = asHashable(rhsPtr.assumingMemoryBound(to: Any.self).pointee) else { return false }
                return lhsValue == rhsValue
            case let .witnessTable(witnessTable):
                return runtime_equalityHelper(lhsPtr, rhsPtr, metadataPointer(type: type), witnessTable)
            case .reference:
                let lhsValue = lhsPtr.assumingMemoryBound(to: UnsafeRawPointer.self).pointee
                let rhsValue = rhsPtr.assumingMemoryBound(to: UnsafeRawPointer.self).pointee
                return lhsValue == rhsValue
            case .function:
                let lhsMirror = lhsPtr.assumingMemoryBound(to: FunctionMirrorImpl.self).pointee
                let rhsMirror = rhsPtr.assumingMemoryBound(to: FunctionMirrorImpl.self).pointee
                return lhsMirror == rhsMirror
            }
        case let .indirect(layout):
            return layout.areEqual(
                lhsPtr.assumingMemoryBound(to: UnsafeRawPointer.self).pointee,
                rhsPtr.assumingMemoryBound(to: UnsafeRawPointer.self).pointee
            )
        }
    }
}

public struct CaptureLayout {
    private var pointer: UnsafeRawPointer

    fileprivate init(count: Int) {
        let countAlignment = MemoryLayout<Int>.alignment
        let fieldAlignemnt = MemoryLayout<CaptureField>.alignment
        let offset = (MemoryLayout<Int>.size + fieldAlignemnt - 1) & ~(fieldAlignemnt - 1)
        let size = offset + MemoryLayout<CaptureField>.stride * count
        let alignment = max(countAlignment, fieldAlignemnt)

        let buffer = UnsafeMutableRawBufferPointer.allocate(byteCount: size, alignment: alignment)
        buffer.baseAddress?.assumingMemoryBound(to: Int.self).initialize(to: (count << 1) | 1)
        self.pointer = UnsafeRawPointer(buffer.baseAddress!)
    }

    fileprivate func add(field: CaptureField, at index: Int) {
        self.fields.baseAddress!.mutable.advanced(by: index).initialize(to: field)
        if !field.isHashable {
            self.pointer.assumingMemoryBound(to: Int.self).mutable.pointee &= ~1
        }
    }

    var isHashable: Bool {
        return pointer.assumingMemoryBound(to: Int.self).pointee & 1 != 0
    }

    var fieldCount: Int {
        return pointer.assumingMemoryBound(to: Int.self).pointee >> 1
    }

    var fields: UnsafeBufferPointer<CaptureField> {
        let alignment = MemoryLayout<CaptureField>.alignment
        let offset = (MemoryLayout<Int>.size + alignment - 1) & ~(alignment - 1)
        let start = pointer.advanced(by: offset).assumingMemoryBound(to: CaptureField.self)
        return UnsafeBufferPointer(start: start, count: self.fieldCount)
    }

    func enumerateReference(ctx: UnsafeRawPointer, block: (CaptureReference) throws -> Void ) rethrows {
        for field in self.fields {
            try field.enumerateReference(ctx: ctx, block: block)
        }
    }

    func areEqual(_ lhs: UnsafeRawPointer, _ rhs: UnsafeRawPointer) -> Bool {
        for f in self.fields {
            if !f.areEqual(lhs, rhs) {
                return false
            }
        }
        return true
    }
}

private func getHashableProtocolWitness(type: Any.Type) -> UnsafeRawPointer? {
    let typeAsPtr = unsafeBitCast(type, to: UnsafeRawPointer.self)
    let hashableDescriptor: UnsafeRawPointer = runtime_getHashableProtocolDescriptor()
    return swift_conformsToProtocol(typeAsPtr, hashableDescriptor)
}

public func equalityHelperImpl<T: Hashable>(_ lhs: UnsafePointer<T>, _ rhs: UnsafePointer<T>) -> Bool {
    return lhs.pointee == rhs.pointee
}

private func asHashable(_ x: Any) -> AnyHashable? {
    if let hashable = x as? AnyHashable {
        return hashable
    }
    guard let info = try? metadata(of: type(of: x)) else { return nil }
    if info.kind == .function {
        if let mirror = try? FunctionMirror(reflecting: x) {
            return AnyHashable(mirror)
        } else if info.size == MemoryLayout<UnsafeRawPointer>.size {
            return getReference(x)
        } else {
            return nil
        }
    } else if isReferenceKind(info.kind) {
        assert(info.size == MemoryLayout<UnsafeRawPointer>.size)
        return getReference(x)
    } else {
        return nil
    }
}

private func isReferenceKind(_ kind: Kind) -> Bool {
    return kind == .class || kind == .foreignClass || kind == .metatype || kind == .objCClassWrapper
}

private func getReference(_ x: Any) -> AnyHashable? {
    var mutableX = x
    return withUnsafePointer(to: &mutableX) {
        let ptr = $0.withMemoryRebound(to: UnsafeRawPointer.self, capacity: 1) {$0.pointee}
        return AnyHashable(ptr)
    }
}

private final class CaptureLayoutCache {
    static let nullLayout = CaptureLayout(count: 0)
    static let instance = CaptureLayoutCache()
    private var data: [UnsafeRawPointer: Result<CaptureLayout, Error>] = [:]
    private var lock = NSLock()

    private init() {}

    public func layout(ctx: UnsafeRawPointer?) throws -> CaptureLayout {
        guard let ctx = ctx else { return CaptureLayoutCache.nullLayout }
        lock.lock()
        defer { lock.unlock() }
        return try self.layoutLocked(ctx: ctx)
    }

    private func layoutLocked(ctx: UnsafeRawPointer) throws -> CaptureLayout {
        let md = ctx.assumingMemoryBound(to: UnsafeRawPointer.self).pointee
        if let existing = data[md] {
            return try existing.get()
        }

        let new = tryBuildLayout(ctx: ctx, md: md)
        data[md] = new
        return try new.get()
    }

    private func tryBuildLayout(ctx: UnsafeRawPointer, md: UnsafeRawPointer) -> Result<CaptureLayout, Error> {
        do {
            return .success(try buildLayout(ctx: ctx, md: md))
        } catch {
            return .failure(error)
        }
    }

    private func buildLayout(ctx: UnsafeRawPointer, md: UnsafeRawPointer) throws -> CaptureLayout {
        let type = unsafeBitCast(md, to: Any.Type.self)
        let kind = Kind(type: type)
        guard kind == .heapLocalVariable else { throw RuntimeError.couldNotGetTypeInfo(type: type, kind: kind) }

        let md = HeapLocalVariableMetadata(type: type)
        if md.numBindings > 0 || md.numMetadataSources > 0 {
            // There are major complications in demangling generic functions
            // There is not much runtime API available to demangle a type:
            //   swift_getTypeByMangledNameInContext() - allows to demangle generic type name in the context of nominal type
            //   swift_getTypeByMangledNameInEnvironment() - allows to demangle generic type name in the context of a function
            //
            // The later seems to be a perfect match for our purposes, but there seems to be no way to obtain one from a compiler.
            // Generic environment is used only to create an instance of generic key path, and it can be obtained from a key path instance.
            //
            // In theory, it might be possible to construct en environment from metadataSources(), but .referenceCapture and
            // .metadataCapture are a problem. If function captures a reference to generic class and generic parameters can be read
            // from medata of that class - compiler strongly prefers that source to bindings. This may lead to a situation where
            // you need to read a field value before knowing types of the previous fields. But to determinate an offset to the field,
            // one needs to know types of all the previous fields. Such cases are not handled even by the swiftRemoteMirror library.
            //
            // Captured values of generic types, whose size depends on the generic parameters, get boxed. So all the remaining types
            // should have a layout which does not depend on the type. So, in theory, even this should be a solvable problem.
            //
            // There seem to be no data struct which would provide size and alignment of the unspecialized generic type.
            // One crazy idea that can be tried here - we can try to specialize generic type with dummy type arguments.
            // But for this to work, dummy type arguments should satisfy all the generic requirements.
            // The Never type conforms to any protocol but still crashes when trying to obtain the type.
            // But even the Never type does not satisfy associated type constraints.
            throw RuntimeError.genericFunctionsAreNotSupported
        }

        let layout = CaptureLayout(count: md.numCaptureTypes)

        var offset = md.offsetToFirstCapture
        offset += MemoryLayout<Any.Type>.size * md.numBindings
        for (i, typeName) in md.capturedTypes().enumerated() {
            let fieldType = try typeName.type(genericContext: nil, genericArguments: nil)
            let fieldKind = Kind(type: fieldType)
            let effectiveType = fieldKind == .opaque ? UnsafeRawPointer.self: fieldType
            let info = try metadata(of: effectiveType)
            let alignedOffset = (offset + info.alignment - 1) & ~(info.alignment - 1)
            offset = alignedOffset + info.size

            if fieldKind == .opaque {
                let indirectPtr = ctx.advanced(by: alignedOffset).assumingMemoryBound(to: UnsafeRawPointer.self).pointee
                let indirectLayout = try self.layoutLocked(ctx: indirectPtr)
                layout.add(field: CaptureField(offset: alignedOffset, typeInfo: .indirect(layout: indirectLayout)), at: i)
            } else {
                let hashable: HashableSupport
                if fieldType == Any.self {
                    hashable = .any
                } else if let hashableWitnessTable = getHashableProtocolWitness(type: fieldType) {
                    hashable = .witnessTable(hashableWitnessTable)
                } else if fieldKind == .function {
                    let funcInfo = try functionInfo(of: fieldType)
                    if funcInfo.callingConvention == .swift {
                        hashable = .function
                    } else if info.size == MemoryLayout<UnsafeRawPointer>.size {
                        hashable = .reference
                    } else {
                        hashable = .none
                    }
                } else if isReferenceKind(fieldKind) {
                    assert(info.size == MemoryLayout<UnsafeRawPointer>.size)
                    hashable = .reference
                } else {
                    hashable = .none
                }
                layout.add(field: CaptureField(offset: alignedOffset, typeInfo: .direct(type: fieldType, hashable: hashable)), at: i)
            }
        }
        return layout
    }
}

private struct FunctionMirrorImpl: Hashable {
    var function: UnsafeRawPointer
    var context: UnsafeRawPointer?

    public func captureLayout() throws -> CaptureLayout {
        return try CaptureLayoutCache.instance.layout(ctx: self.context)
    }

    public func capturedValues() throws -> [Any] {
        guard let ctx = self.context else { return [] }
        let layout = try self.captureLayout()
        var result: [Any] = []
        layout.enumerateReference(ctx: ctx) {
            result.append($0.value)
        }
        return result
    }

    public func captureReferences() throws -> [CaptureReference] {
        guard let ctx = self.context else { return [] }
        let layout = try self.captureLayout()
        var result: [CaptureReference] = []
        layout.enumerateReference(ctx: ctx) {
            result.append($0)
        }
        return result
    }

    public static func == (lhs: FunctionMirrorImpl, rhs: FunctionMirrorImpl) -> Bool {
        if lhs.function != rhs.function {
            // Totally unrelated blocks
            return false
        }

        if lhs.context == rhs.context {
            // Perfect match
            return true
        }

        guard let lhsCtx = lhs.context else { return false }
        guard let rhsCtx = rhs.context else { return false }

        let lhsMD = lhsCtx.assumingMemoryBound(to: UnsafeRawPointer.self).pointee
        let rhsMD = rhsCtx.assumingMemoryBound(to: UnsafeRawPointer.self).pointee
        guard lhsMD == rhsMD else { return false }

        if let layout = try? lhs.captureLayout(), layout.isHashable {
            return layout.areEqual(lhsCtx, rhsCtx)
        } else {
            // We failed to get a layout
            // Fallback to bitwise comparison
            // We already checked contexts, so we know that's not a match
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.function)
    }
}

public struct FunctionMirror<T>: Hashable {
    public let value: T // To retain the context, in case FunctionMirror outlives its parameter.
    private let impl: FunctionMirrorImpl

    public var function: UnsafeRawPointer {
        return self.impl.function
    }

    public var context: UnsafeRawPointer? {
        return self.impl.context
    }

    public init(reflecting f: T) throws {
        let info = try functionInfo(of: f)
        if info.callingConvention != .swift {
            throw RuntimeError.unsupportedCallingConvention(function: f, callingConvention: info.callingConvention)
        }

        self.value = f

        var mutableF = f
        self.impl = withUnsafeBytes(of: &mutableF) {
            assert($0.count >= MemoryLayout<FunctionMirrorImpl>.size)
            return $0.baseAddress!.assumingMemoryBound(to: FunctionMirrorImpl.self).pointee
        }
    }

    public func captureLayout() throws -> CaptureLayout {
        return try self.impl.captureLayout()
    }

    public func capturedValues() throws -> [Any] {
        return try self.impl.capturedValues()
    }

    public func captureReferences() throws -> [CaptureReference] {
        return try self.impl.captureReferences()
    }

    public static func == (lhs: FunctionMirror<T>, rhs: FunctionMirror<T>) -> Bool {
        return lhs.impl == rhs.impl
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.impl)
    }
}
