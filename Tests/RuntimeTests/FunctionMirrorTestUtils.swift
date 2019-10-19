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

import XCTest
@testable import Runtime

// Swift refuses to perform condition cast to optional types
// But if it does not know that destination type is an optional type, that it can
// Note that this returns double optional
func cast<T>(_ from: Any, to: T.Type) -> T? {
    return from as? T
}

func XCTAssertAnyEqual(_ lhs: Any, _ rhs: Any, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if (lhs as! AnyHashable) != (rhs as! AnyHashable) {
        XCTFail(message, file: file, line: line)
    }
}

func XCTAssertTypeEqual(_ lhs: Any.Type, _ rhs: Any.Type, _ message: String = "", file: StaticString = #file, line: UInt = #line) {
    if unsafeBitCast(lhs, to: UnsafeRawPointer.self) != unsafeBitCast(rhs, to: UnsafeRawPointer.self) {
        XCTFail(message, file: file, line: line)
    }
}

func mirror(reflecting f: Any) throws -> FunctionMirror {
    let m = try FunctionMirror(reflecting: f)
    let values = try m.capturedValues()
    if values.count == 1 {
        let value = values[0]
        let info = try metadata(of: type(of: value))
        if info.kind == .function {
            return try FunctionMirror(reflecting: value)
        }
    }
    return m
}
