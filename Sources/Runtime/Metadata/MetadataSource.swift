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
    private static func decodeClosureBinding(scanner: inout ByteScanner) -> MetadataSource? {
        guard let index = scanner.scanNatural() else { return nil }
        return .closureBinding(index: index)
    }

    private static func decodeReferenceCapture(scanner: inout ByteScanner) -> MetadataSource? {
        guard let index = scanner.scanNatural() else { return nil }
        return .referenceCapture(index: index)
    }

    private static func decodeMetadataCapture(scanner: inout ByteScanner) -> MetadataSource? {
        guard let index = scanner.scanNatural() else { return nil }
        return .metadataCapture(index: index)
    }

    private static func decodeGenericArgument(scanner: inout ByteScanner) -> MetadataSource? {
        guard let index = scanner.scanNatural() else { return nil }
        guard let base = decode(scanner: &scanner) else { return nil }
        if !scanner.scan(scalar: "_") { return nil }
        return .genericArgument(index: index, base: base)
    }

    public static func decode(scanner: inout ByteScanner) -> MetadataSource? {
        switch scanner.scanScalar() {
            case "B": return decodeClosureBinding(scanner: &scanner)
            case "R": return decodeReferenceCapture(scanner: &scanner)
            case "M": return decodeMetadataCapture(scanner: &scanner)
            case "G": return decodeGenericArgument(scanner: &scanner)
            case "S": return .`self`
            default: return nil
        }
    }

    public init(buffer: UnsafeBufferPointer<UInt8>) throws {
        var scanner = ByteScanner(buffer: buffer)
        guard let source = Self.decode(scanner: &scanner), scanner.atEnd() else {
            throw RuntimeError.unexpectedMetadataSource(buffer: buffer)
        }
        self = source
    }

    public init(string: String) throws {
        var stringCopy = string
        self = try stringCopy.withUTF8 {
            try Self(buffer: $0)
        }
    }
}
