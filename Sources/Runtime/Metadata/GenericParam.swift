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

struct GenericParam: Hashable {
    var depth: Int
    var index: Int

    init(depth: Int, index: Int) {
        self.depth = depth
        self.index = index
    }

    init(buffer: UnsafeBufferPointer<UInt8>) throws {
        var scanner = ByteScanner(buffer: buffer)
        guard let result = GenericParam.parse(scanner: &scanner), scanner.atEnd() else {
            throw RuntimeError.unexpectedGenericParam(buffer: buffer)
        }
        self = result
    }

    init(typeName: String) throws {
        var typeNameCopy = typeName
        self = try typeNameCopy.withUTF8 { try Self(buffer: $0) }
    }

    init(typeName: MangledTypeName) throws {
        try self.init(buffer: typeName.buffer)
    }

    private static func parse(scanner: inout ByteScanner) -> GenericParam? {
        if scanner.scan(scalar: "x") {
            return GenericParam(depth: 0, index: 0)
        }
        if !scanner.scan(scalar: "q") {
            return nil
        }
        if scanner.scan(scalar: "z") {
            return GenericParam(depth: 0, index: 0)
        }

        if scanner.scan(scalar: "d") {
            guard let depth = parseIndex(scanner: &scanner) else { return nil }
            guard let index = parseIndex(scanner: &scanner) else { return nil }
            return GenericParam(depth: depth + 1, index: index)
        } else {
            guard let index = parseIndex(scanner: &scanner) else { return nil }
            return GenericParam(depth: 0, index: index + 1)
        }
    }

    private static func parseIndex(scanner: inout ByteScanner) -> Int? {
        if scanner.scan(scalar: "_") {
            return 0
        }
        if let index = scanner.scanNatural(), scanner.scan(scalar: "_") {
            return index + 1
        }
        return nil
    }
}
