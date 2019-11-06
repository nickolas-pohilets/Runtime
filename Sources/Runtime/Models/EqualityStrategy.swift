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

public enum EqualityStrategy {
    case none
    case witnessTable(Any.Type, UnsafeRawPointer)
    case function
    case raw(Int)
    case tuple([(Int, EqualityStrategy)])
    case existential(Any.Type)

    public init(type: Any.Type) throws {
        self = try EqualityStrategy(info: try metadata(of: type))
    }

    init(info: MetadataInfo) throws {
        let type = info.type
        let kind = info.kind
        if let hashableWitnessTable = getHashableProtocolWitness(type: type) {
            self = .witnessTable(type, hashableWitnessTable)
        } else if kind == .function {
            let funcInfo = try functionInfo(of: type)
            if funcInfo.callingConvention == .swift {
                self = .function
            } else {
                self = .raw(info.size)
            }
        } else if isRawKind(kind) {
            self = .raw(info.size)
        } else if kind == .tuple {
            let info = try typeInfo(of: type)
            let fields = try info.properties.map { ($0.offset, try EqualityStrategy(type: $0.type)) }
            self = .tuple(fields)
        } else if kind == .existential {
            self = .existential(type)
        } else {
            self = .none
        }
    }

    public func areEqual(lhsPtr: UnsafeRawPointer, rhsPtr: UnsafeRawPointer) -> Bool {
        switch self {
        case .none:
            return false
        case let .witnessTable(type, witnessTable):
            return runtime_equalityHelper(lhsPtr, rhsPtr, metadataPointer(type: type), witnessTable)
        case .function:
            let lhsMirror = lhsPtr.assumingMemoryBound(to: FunctionMirrorImpl.self).pointee
            let rhsMirror = rhsPtr.assumingMemoryBound(to: FunctionMirrorImpl.self).pointee
            return lhsMirror == rhsMirror
        case let .raw(size):
            let lhsBuffer = UnsafeRawBufferPointer(start: lhsPtr, count: size)
            let rhsBuffer = UnsafeRawBufferPointer(start: rhsPtr, count: size)
            return lhsBuffer.elementsEqual(rhsBuffer)
        case let .tuple(fields):
            for (offset, fieldStategy) in fields {
                let lhsFieldPtr = lhsPtr.advanced(by: offset)
                let rhsFieldPtr = rhsPtr.advanced(by: offset)
                if (!fieldStategy.areEqual(lhsPtr: lhsFieldPtr, rhsPtr: rhsFieldPtr)) {
                    return false
                }
            }
            return true
        case let .existential(type):
            return anyAreEqual(
                lhs: getters(type: type).get(from: lhsPtr),
                rhs: getters(type: type).get(from: rhsPtr)
            )
        }
    }

    public static func areEqual<T>(_ lhs: T, _ rhs: T) throws -> Bool {
        let eq = try Self(type: T.self)
        var lhsCopy = lhs
        var rhsCopy = rhs
        return withUnsafePointer(to: &lhsCopy) { lhsPtr in
            withUnsafePointer(to: &rhsCopy) { rhsPtr in
                return eq.areEqual(lhsPtr: lhsPtr.raw, rhsPtr: rhsPtr.raw)
            }
        }
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

private func anyAreEqual(lhs: Any, rhs: Any) -> Bool {
    let lhsHashable = lhs as? AnyHashable
    let rhsHashable = rhs as? AnyHashable
    if lhsHashable != nil || rhsHashable != nil {
        return lhsHashable == rhsHashable
    }
    var lhsCopy = lhs
    var rhsCopy = rhs
    let res: Bool? = try? withExistentialValuePointer(of: &lhsCopy, dereferenceClass: false) { (lhsPtr, lhsType) in
        return try withExistentialValuePointer(of: &rhsCopy, dereferenceClass: false) { (rhsPtr, rhsType) in
            guard lhsType == rhsType else { return false }
            return try EqualityStrategy(type: lhsType).areEqual(lhsPtr: lhsPtr, rhsPtr: rhsPtr)
        }
    }
    return res ?? false
}

private func isRawKind(_ kind: Kind) -> Bool {
    return kind == .class || kind == .foreignClass || kind == .metatype || kind == .objCClassWrapper || kind == .existentialMetatype
}

private func getReference(_ x: Any) -> AnyHashable? {
    var mutableX = x
    return withUnsafePointer(to: &mutableX) {
        let ptr = $0.withMemoryRebound(to: UnsafeRawPointer.self, capacity: 1) {$0.pointee}
        return AnyHashable(ptr)
    }
}
