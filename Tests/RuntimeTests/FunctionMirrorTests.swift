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

fileprivate struct MyStruct: Hashable {
    let a: Int
    let b: String
    let c: [Bool]
}

fileprivate class MyClass {
    var value: String

    init(value: String) {
        self.value = value
    }

    func dump() {
        print(self.value)
    }
}

class FunctionMirrorTests: XCTestCase {
    
//    static var allTests: [(String, (FunctionMirrorTests) -> () throws -> Void)] {
//        return [
//            ("testIt", testIt),
//        ]
//    }

    private func makeEmptyFunc() -> () -> Void {
        return { print("boom!") }
    }
    
    private func makeBuiltIn(_ a: Int, _ s: String, _ b: Int, _ f: Bool) -> () -> Void {
        return { if f { print(a + b) } else { print(s) } }
    }

    private func makeArray( _ x: [String]) -> () -> Void {
        return { print(x) }
    }

    private func makeStruct(_ s: MyStruct) -> () -> Void {
        return { print(s) }
    }

    private func makeMethod(_ value: String) -> () -> Void {
        return MyClass(value: value).dump
    }

    private func makeGeneric<T: Hashable, U: Hashable>(x: T, y: U) -> () -> Void {
        return { print(x, y) }
    }

    struct Try<T: Equatable> {
        static func eq(_ a: Any, _ b: Any) -> Bool? {
            if let ax = a as? T {
                if let bx = b as? T {
                    return ax == bx
                } else {
                    return false
                }
            } else {
                if b is T {
                    return false
                } else {
                    return nil
                }
            }
        }
    }

    func eq(_ a: [Any], _ b: [Any]) -> Bool {
        return a.elementsEqual(b) { (ea, eb) in
            Try<Bool>.eq(ea, eb) ?? Try<Int>.eq(ea, eb) ?? Try<String>.eq(ea, eb) ?? false
        }
    }

    func mirror(reflecting f: Any) throws -> FunctionMirror {
        let m = try FunctionMirror(reflecting: f)
        if m.capturedValues.count == 1 {
            let value = m.capturedValues[0]
            let info = try metadata(of: type(of: value))
            if info.kind == .function {
                return try FunctionMirror(reflecting: value)
            }
        }
        return m
    }

    func testEmpty() throws {
        let f = makeEmptyFunc()
        let m = try mirror(reflecting: f)
        XCTAssert(m.capturedValues.isEmpty)
    }
    
    func testBuiltIn() throws {
        let f = makeBuiltIn(37, "abc", 42, true)
        let m = try mirror(reflecting: f)
        XCTAssertEqual(m.capturedValues.count, 4)
        XCTAssertEqual(m.capturedValues[0] as? Bool, true)
        XCTAssertEqual(m.capturedValues[1] as? Int, 37)
        XCTAssertEqual(m.capturedValues[2] as? Int, 42)
        XCTAssertEqual(m.capturedValues[3] as? String, "abc")
    }

    func testArray() throws {
        let x = ["abc", "def", "long long long string that would not fit into inline buffer"]
        let f = makeArray(x)
        let m = try mirror(reflecting: f)
        XCTAssertEqual(m.capturedValues.count, 1)
        XCTAssertEqual(m.capturedValues[0] as? [String], x)
    }

    func testStruct() throws {
        let s = MyStruct(a: 22, b: "xyz", c: [true, false, true])
        let f = makeStruct(s)
        let m = try mirror(reflecting: f)
        XCTAssertEqual(m.capturedValues.count, 1)
        XCTAssertEqual(m.capturedValues[0] as? MyStruct, s)
    }

    func testMethod() throws {
        let f = makeMethod("hello")
        let m = try mirror(reflecting: f)
        XCTAssertEqual(m.capturedValues.count, 2)
        if let obj = m.capturedValues[0] as? MyClass {
            XCTAssertEqual(obj.value, "hello")
        } else {
            XCTFail("Failed to read captured instance")
        }
        XCTAssert(m.capturedValues[1] is UnsafeRawPointer)
    }

    func skip_testGeneric() throws {
        let s = MyStruct(a: 22, b: "xyz", c: [true, false, true])
        let f = makeGeneric(x: [s], y: s)
        let m = try mirror(reflecting: f)
        XCTAssertEqual(m.capturedValues.count, 2)
        XCTAssertEqual(m.capturedValues[0] as? [MyStruct], [s])
        XCTAssertEqual(m.capturedValues[1] as? MyStruct, s)
    }
}
