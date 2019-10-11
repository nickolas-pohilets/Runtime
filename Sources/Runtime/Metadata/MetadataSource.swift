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

indirect enum MetadataSource: Hashable {
    /// Metadata is a closure binding at specified index
    case closureBinding(index: Int)
    /// Metadata is a type of the reference captured in the field at  specified index
    case referenceCapture(index: Int)
    /// Metadata is captured in the field at specified index
    case metadataCapture(index: Int)
    /// Metadata is a generic argument of nominal type specified by `base`
    case genericArgument(index: Int, base: MetadataSource)
    /// This one seems to be unused
    case `self`
}

extension MetadataSource {
    private static func decodeNatural(ptr: inout UnsafePointer<UInt8>) -> Int? {
        var value = 0
        while ptr.pointee >= UnicodeScalar("0").value && ptr.pointee <= UnicodeScalar("9").value {
            let digit = Int(UInt32(ptr.pointee) - UnicodeScalar("0").value)
            ptr = ptr.advanced(by: 1)
            if value > (Int.max - digit) / 10 {
                // Overflow
                return nil
            }
            value = value * 10 + digit
        }
        return value
    }

    private static func decodeClosureBinding(ptr: inout UnsafePointer<UInt8>) -> MetadataSource? {
        guard let index = decodeNatural(ptr: &ptr) else { return nil }
        return .closureBinding(index: index)
    }

    private static func decodeReferenceCapture(ptr: inout UnsafePointer<UInt8>) -> MetadataSource? {
        guard let index = decodeNatural(ptr: &ptr) else { return nil }
        return .referenceCapture(index: index)
    }

    private static func decodeMetadataCapture(ptr: inout UnsafePointer<UInt8>) -> MetadataSource? {
        guard let index = decodeNatural(ptr: &ptr) else { return nil }
        return .metadataCapture(index: index)
    }

    private static func decodeGenericArgument(ptr: inout UnsafePointer<UInt8>) -> MetadataSource? {
        guard let index = decodeNatural(ptr: &ptr) else { return nil }
        guard let base = decode(ptr: &ptr) else { return nil }
        if ptr.pointee != UnicodeScalar("_").value { return nil }
        ptr = ptr.advanced(by: 1)
        return .genericArgument(index: index, base: base)
    }

    public static func decode(ptr: inout UnsafePointer<UInt8>) -> MetadataSource? {
        let current = ptr.pointee
        ptr = ptr.advanced(by: 1)
        switch UInt32(current) {
            case UnicodeScalar("B").value: return decodeClosureBinding(ptr: &ptr)
            case UnicodeScalar("R").value: return decodeReferenceCapture(ptr: &ptr)
            case UnicodeScalar("M").value: return decodeMetadataCapture(ptr: &ptr)
            case UnicodeScalar("G").value: return decodeGenericArgument(ptr: &ptr)
            case UnicodeScalar("S").value: return .`self`
            default: return nil
        }
    }

    public init(ptr: UnsafeRawPointer) throws {
        var ptrCopy = ptr.assumingMemoryBound(to: UInt8.self)
        guard let source = Self.decode(ptr: &ptrCopy), ptrCopy.pointee == 0 else {
            let str = String(utf8String: ptr.assumingMemoryBound(to: CChar.self))!
            throw RuntimeError.unexpectedMetadataSource(source: str)
        }
        self = source
    }

    public init(string: String) throws {
        var stringCopy = string
        self = try stringCopy.withUTF8 {
            try Self(ptr: $0.baseAddress!.raw)
        }
    }
}
