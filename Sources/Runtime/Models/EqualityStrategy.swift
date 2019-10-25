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
    case reference
    case tuple([(Int, EqualityStrategy)])
    case existential(Any.Type)

    init(type: Any.Type) throws {
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
            } else if info.size == MemoryLayout<UnsafeRawPointer>.size {
                self = .reference
            } else {
                self = .none
            }
        } else if isReferenceKind(kind) {
            assert(info.size == MemoryLayout<UnsafeRawPointer>.size)
            self = .reference
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

    func areEqual(_ lhs: UnsafeRawPointer, _ rhs: UnsafeRawPointer) -> Bool {
        switch self {
        case .none:
            return false
        case let .witnessTable(type, witnessTable):
            return runtime_equalityHelper(lhs, rhs, metadataPointer(type: type), witnessTable)
        case .function:
            let lhsMirror = lhs.assumingMemoryBound(to: FunctionMirrorImpl.self).pointee
            let rhsMirror = rhs.assumingMemoryBound(to: FunctionMirrorImpl.self).pointee
            return lhsMirror == rhsMirror
        case .reference:
            let lhsValue = lhs.assumingMemoryBound(to: UnsafeRawPointer.self).pointee
            let rhsValue = rhs.assumingMemoryBound(to: UnsafeRawPointer.self).pointee
            return lhsValue == rhsValue
        case let .tuple(fields):
            for (offset, fieldStategy) in fields {
                let lhsField = lhs.advanced(by: offset)
                let rhsField = rhs.advanced(by: offset)
                if (!fieldStategy.areEqual(lhsField, rhsField)) {
                    return false
                }
            }
            return true
        case let .existential(type):
            return anyAreEqual(
                lhs: getters(type: type).get(from: lhs),
                rhs: getters(type: type).get(from: rhs)
            )
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
            return try EqualityStrategy(type: lhsType).areEqual(lhsPtr, rhsPtr)
        }
    }
    return res ?? false
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
