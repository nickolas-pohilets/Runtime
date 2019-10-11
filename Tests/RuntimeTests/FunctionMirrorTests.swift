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

struct ArrayAndInt: Hashable {
    var a: [String]
    var b: Int
}

private extension Hashable {
    func makeGeneric() -> () -> Void {
        return { print(self) }
    }
}

class GenericProvider<T: Hashable> {
    let x: T

    init(x: T) {
        self.x = x
    }

    func makeGeneric(_ y: T) -> () -> Void {
        return {
            if (self.x == y) {
                print("equal")
            } else {
                print("not equal")
            }
        }
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

    private func makeSharedContext() -> (() -> Void, () -> Void) {
        var foo: [String] = ["foo", "bar", "baz"]
        let f1 = {
            foo.append("qux")
        }
        let f2 = {
            foo.append("zop")
        }
        return (f1, f2)
    }

    private func makeByRef() -> (() -> ArrayAndInt, () -> ArrayAndInt) {
        var foo: [String] = ["foo", "bar", "baz"]
        var k: Int = 42
        var z: Int = 7
        let f1 = { () -> ArrayAndInt in
            foo.append("qux")
            z *= 2
            return ArrayAndInt(a: foo, b: z)
        }
        let f2 = { () -> ArrayAndInt in
            foo.append("zop")
            k += 5
            return ArrayAndInt(a: foo, b: k)
        }
        return (f1, f2)
    }

    private func makeGeneric<T: Hashable, U: Hashable>(x: T, y: U) -> () -> Void {
        return { print(x, y) }
    }

    private func makeGeneric2<T: Hashable>(x: T) -> () -> Void {
        let y: [T] = [x, x]
        let z: T? = nil
        return { print(x, y, z as Any) }
    }

    struct Foo<T: Hashable, U: Hashable>: Hashable {
        var x: T
        var y: U
    }

    private func makeGenericStruct<T: Hashable, U: Hashable>(x: T, y: U) -> Any {
        return Foo(x: x, y: y)
    }

    private func makeGenericMD<T>(type: T.Type) -> () -> Void {
        let x: [T] = []
        return { print(type, x) }
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

    func testSharedContext() throws {
        // Optimized case - variable is captured as if by value, but instead context is shared between two closures
        let (f1, f2) = makeSharedContext()
        var ctx: UnsafeRawPointer? = nil
        do {
            let m1 = try mirror(reflecting: f1)
            let m2 = try mirror(reflecting: f2)
            XCTAssertEqual(m1.capturedValues.count, 1)
            XCTAssertEqual(m1.capturedValues[0] as? [String], ["foo", "bar", "baz"])
            //XCTAssertEqual(m1.capturedValues[1] as? Int, 42)
            XCTAssertEqual(m2.capturedValues.count, 1)
            XCTAssertEqual(m2.capturedValues[0] as? [String], ["foo", "bar", "baz"])
            //XCTAssertEqual(m2.capturedValues[1] as? Int, 42)
            XCTAssertEqual(m1.context, m2.context)
            ctx = m1.context
        }
        f2()
        do {
            let m1 = try mirror(reflecting: f1)
            let m2 = try mirror(reflecting: f2)
            XCTAssertEqual(m1.capturedValues.count, 1)
            XCTAssertEqual(m1.capturedValues[0] as? [String], ["foo", "bar", "baz", "zop"])
            //XCTAssertEqual(m1.capturedValues[1] as? Int, 47)
            XCTAssertEqual(m2.capturedValues.count, 1)
            XCTAssertEqual(m2.capturedValues[0] as? [String], ["foo", "bar", "baz", "zop"])
            //XCTAssertEqual(m2.capturedValues[1] as? Int, 47)
            XCTAssertEqual(m1.context, m2.context)
            XCTAssertEqual(m1.context, ctx)
        }
    }

    func testByRef() throws {
        let (f1, f2) = makeByRef()
        let m1 = try mirror(reflecting: f1)
        XCTAssertEqual(m1.capturedValues.count, 2)
        let r11 = m1.capturedValues[0] as! ByRefMirror
        XCTAssertTypeEqual(try r11.type(), [String].self)
        XCTAssertAnyEqual(try r11.value(), ["foo", "bar", "baz"])
        let r12 = m1.capturedValues[1] as! ByRefMirror
        XCTAssertTypeEqual(try r12.type(), Int.self)
        XCTAssertAnyEqual(try r12.value(), 7)
        let m2 = try mirror(reflecting: f2)
        XCTAssertEqual(m2.capturedValues.count, 2)
        let r21 = m2.capturedValues[0] as! ByRefMirror
        XCTAssertTypeEqual(try r21.type(), [String].self)
        XCTAssertAnyEqual(try r21.value(), ["foo", "bar", "baz"])
        let r22 = m2.capturedValues[1] as! ByRefMirror
        XCTAssertTypeEqual(try r22.type(), Int.self)
        XCTAssertAnyEqual(try r22.value(), 42)
        XCTAssertEqual(r11, r21)
        XCTAssertNotEqual(r12, r22)

        XCTAssertEqual(f1(), ArrayAndInt(a: ["foo", "bar", "baz", "qux"], b: 14))
        XCTAssertAnyEqual(try r11.value(), ["foo", "bar", "baz", "qux"])
        XCTAssertAnyEqual(try r12.value(), 14)
        try r11.setValue([] as [String])
        try r12.setValue(2)
        XCTAssertEqual(f1(), ArrayAndInt(a: ["qux"], b: 4))

        XCTAssertEqual(f2(), ArrayAndInt(a: ["qux", "zop"], b: 47))
        XCTAssertAnyEqual(try r21.value(), ["qux", "zop"])
        XCTAssertAnyEqual(try r22.value(), 47)
        try r21.setValue(["xyz"] as [String])
        try r22.setValue(1)
        XCTAssertEqual(f2(), ArrayAndInt(a: ["xyz", "zop"], b: 6))
    }

    func testMetadataSource() {
        XCTAssertEqual(try MetadataSource(string: "B1"), MetadataSource.closureBinding(index: 1))
        XCTAssertEqual(try MetadataSource(string: "R0"), MetadataSource.referenceCapture(index: 0))
        XCTAssertEqual(try MetadataSource(string: "M106"), MetadataSource.metadataCapture(index: 106))
        XCTAssertEqual(try MetadataSource(string: "G0R1_"), MetadataSource.genericArgument(index: 0, base: .referenceCapture(index: 1)))
        XCTAssertEqual(try MetadataSource(string: "S"), MetadataSource.`self`)
    }

    func testGeneric() throws {
        let s = MyStruct(a: 22, b: "xyz", c: [true, false, true])
//        let g = makeGenericStruct(x: [s], y: s)
//        let ti = try typeInfo(of: type(of: g))
//        print(ti)

        // Case 1
        //  types:
        //    "xz_x_q_SHRzSHR_r0_lXX"
        //    "q_z_x_q_SHRzSHR_r0_lXX"
        //  sources:
        //    "x" -> B0
        //    "q_" -> B1
        //let f = makeGeneric(x: [s], y: s)

        // Case 2:
        //  types:
        //    "xz_x_SHRzlXX"
        //    "SayxG"
        //    "xSgz_x_SHRzlXX"
        //  sources:
        //    "x" -> B0
        //let f = makeGeneric2(x: s)

        // Case 3:
        //  types:
        //     "xz_x_SHRzlXX"
        //  sources:
        //     "x" -> "B0"
        // let f = s.makeGeneric()

        // Case 4:
        //  types:
        //    {01:0xfffffe84800000d0}yxG
        //    xz_x_SHRzlXX
        //  sources:
        //     "x" -> "G0R0_"
        //     no bindings
        //let f = GenericProvider<String>(x: "abc").makeGeneric("xyz")

        //  'B' -> ClosureBinding
        //  'R' -> ReferenceCapture
        //  'M' -> MetadataCapture
        //  'G' -> GenericArgument
        //  'S' -> Self
        //let f = makeGenericMD(type: MyStruct.self)
        let f = makeGeneric(x: 0xaaaaaaaaaaaa, y: 0xbbbbbbbbbbbb)
        let m = try mirror(reflecting: f)
        XCTAssertEqual(m.capturedValues.count, 2)
        XCTAssertEqual(m.capturedValues[0] as? [MyStruct], [s])
        XCTAssertEqual(m.capturedValues[1] as? MyStruct, s)
    }
}
