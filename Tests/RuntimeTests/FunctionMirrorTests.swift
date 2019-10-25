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

fileprivate struct NonHashableStruct {
    let a: Int
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

fileprivate class HashableBase: Hashable {
    var value: String
    init(value: String) {
        self.value = value
    }

    static func == (lhs: HashableBase, rhs: HashableBase) -> Bool {
        return lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

fileprivate class HashableDerivedA: HashableBase {}
fileprivate class HashableDerivedB: HashableBase {}

struct ArrayAndInt: Hashable {
    var a: [String]
    var b: Int
}

class FunctionMirrorTests: XCTestCase {
    
//    static var allTests: [(String, (FunctionMirrorTests) -> () throws -> Void)] {
//        return [
//            ("testIt", testIt),
//        ]
//    }

    @inline(never)
    private func makeEmptyFunc() -> () -> Void {
        return { print("boom!") }
    }
    
    @inline(never)
    private func makeBuiltIn(_ a: Int, _ s: String, _ b: Int, _ f: Bool) -> () -> Void {
        return { if f { print(a + b) } else { print(s) } }
    }

    @inline(never)
    private func makeBuiltInAsAny(_ a: Int, _ s: String, _ b: Int, _ f: Bool) -> Any {
        // Wrapping into Any should be encapsulated into a funciton, otherwise different reabstraction thunks are created
        return { if f { print(a + b) } else { print(s) } }
    }

    @inline(never)
    private func makeArray( _ x: [String]) -> () -> Void {
        return { print(x) }
    }

    @inline(never)
    private func makeStruct(_ s: MyStruct) -> () -> Void {
        return { print(s) }
    }

    @inline(never)
    private func makeAny(_ x: Any) -> () -> Void {
        return { print(x) }
    }

    @inline(never)
    private func makeMethod(instance: MyClass) -> () -> Void {
        return instance.dump
    }

    @inline(never)
    private func makeMethod(value: String) -> (String) -> Bool {
        return value.hasPrefix
    }

    @inline(never)
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

    @inline(never)
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

    func testEmpty() throws {
        let f = makeEmptyFunc()
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssert(values.isEmpty)

        let g = makeEmptyFunc();
        let n = try mirror(reflecting: g)
        XCTAssertEqual(m, n)
    }
    
    func testBuiltIn() throws {
        let f = makeBuiltIn(37, "abc", 42, true)
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 4)
        XCTAssertEqual(values[0] as? Bool, true)
        XCTAssertEqual(values[1] as? Int, 37)
        XCTAssertEqual(values[2] as? Int, 42)
        XCTAssertEqual(values[3] as? String, "abc")

        XCTAssertEqual(m, try mirror(reflecting: makeBuiltIn(37, "abc", 42, true)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeBuiltIn(35, "abc", 42, true)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeBuiltIn(37, "xyz", 42, true)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeBuiltIn(37, "abc", -1, true)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeBuiltIn(37, "abc", 42, false)))
    }

    func testArray() throws {
        let x = ["abc", "def", "long long long string that would not fit into inline buffer"]
        let f = makeArray(x)
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0] as? [String], x)

        XCTAssertEqual(m, try mirror(reflecting: makeArray(["abc", "def", "long long long string that would not fit into inline buffer"])))
        XCTAssertNotEqual(m, try mirror(reflecting: makeArray(["abc", "def"])))
    }

    func testStruct() throws {
        let s = MyStruct(a: 22, b: "xyz", c: [true, false, true])
        let f = makeStruct(s)
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0] as? MyStruct, s)

        XCTAssertEqual(m, try mirror(reflecting: makeStruct(MyStruct(a: 22, b: "xyz", c: [true, false, true]))))
        XCTAssertNotEqual(m, try mirror(reflecting: makeStruct(MyStruct(a: 21, b: "xyz", c: [true, false, true]))))
        XCTAssertNotEqual(m, try mirror(reflecting: makeStruct(MyStruct(a: 22, b: "abc", c: [true, false, true]))))
        XCTAssertNotEqual(m, try mirror(reflecting: makeStruct(MyStruct(a: 22, b: "xyz", c: [true, true, true]))))
    }

    func testAnyInt() throws {
        let f = makeAny(42)
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0] as? Int, 42)

        XCTAssertEqual(m, try mirror(reflecting: makeAny(42)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(43)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny("abc")))
    }

    func testAnyString() throws {
        let f = makeAny("abc")
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0] as? String, "abc")

        XCTAssertEqual(m, try mirror(reflecting: makeAny("abc")))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny("xyz")))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(42)))
    }

    func testAnyArray() throws {
        let x = [true, false, nil]
        let f = makeAny(x)
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0] as? [Bool?], x)

        XCTAssertEqual(m, try mirror(reflecting: makeAny([true, false, nil])))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny([false, nil, true])))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(42)))
    }

    func testAnyHashableStruct() throws {
        let s = MyStruct(a: 22, b: "xyz", c: [true, false, true])
        let f = makeAny(s)
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0] as? MyStruct, s)

        XCTAssertEqual(m, try mirror(reflecting: makeAny(MyStruct(a: 22, b: "xyz", c: [true, false, true]))))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(MyStruct(a: 21, b: "abc", c: [true, true, true]))))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(42)))
    }

    func testAnyNonHashableStruct() throws {
        let s = NonHashableStruct(a: 22)
        let f = makeAny(s)
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual((values[0] as? NonHashableStruct)?.a, 22)

        XCTAssertEqual(m, try mirror(reflecting: f))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(NonHashableStruct(a: 22))))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(NonHashableStruct(a: 21))))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(22)))
    }

    func testAnyNonHashableClass() throws {
        let c = MyClass(value: "abc")
        let f = makeAny(c)
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        XCTAssert(values[0] as? MyClass === c)

        XCTAssertEqual(m, try mirror(reflecting: makeAny(c)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(MyClass(value: "abc"))))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(42)))
    }

    func testAnyHashableClass() throws {
        let c1: HashableBase = HashableDerivedA(value: "abc")
        let c2: HashableBase = HashableDerivedB(value: "abc")
        XCTAssertEqual(c1, c2)
        let f = makeAny(c1)
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        XCTAssert(values[0] as? HashableDerivedA === c1)

        XCTAssertEqual(m, try mirror(reflecting: makeAny(c2)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(HashableDerivedA(value: "xyz"))))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(42)))
    }

    func testAnyObjC() throws {
        let c1 = NSArray()
        let c2 = NSArray()
        XCTAssertEqual(c1, c2)
        let f = makeAny(c1)
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        XCTAssert(values[0] as? NSArray === c1)

        XCTAssertEqual(m, try mirror(reflecting: makeAny(c2)))
        XCTAssertEqual(m, try mirror(reflecting: makeAny([] as NSArray)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(["abc"] as NSArray)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny([])))
    }

    func testAnyType() throws {
        let t1: Any.Type = String.self
        let t2: Any.Type = Int.self
        let f = makeAny(t1)
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(String(describing: values[0]), "String")

        XCTAssertEqual(m, try mirror(reflecting: makeAny(t1)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(t2)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny("")))
    }

    func testAnyFunction() throws {
        let a = makeBuiltInAsAny(37, "abc", 42, true)
        let b = makeBuiltInAsAny(37, "abc", 42, true)
        let c = makeBuiltInAsAny(42, "xyz", -1, false)
        XCTAssertEqual(try mirror(reflecting: a), try mirror(reflecting: b))

        let f = makeAny(a)
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        let mx = try mirror(reflecting: values[0])
        let my = try mirror(reflecting: a)
        XCTAssertEqual(mx, my)

        XCTAssertEqual(m, try mirror(reflecting: makeAny(b)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(c)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny("")))
    }

    func testAnyTuple() throws {
        let f = makeAny((42, "abc"))
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        if let value = values[0] as? (Int, String) {
            XCTAssertEqual(value.0, 42)
            XCTAssertEqual(value.1, "abc")
        } else {
            XCTFail("Failed to read captured tuple")
        }

        XCTAssertEqual(m, try mirror(reflecting: makeAny((42, "abc"))))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny((-1, "xyz"))))
        XCTAssertNotEqual(m, try mirror(reflecting: makeAny(())))
    }

    func testClassMethod() throws {
        let obj1 = MyClass(value: "hello")
        let obj2 = MyClass(value: "hello")
        let f = makeMethod(instance: obj1)
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 2)
        if let obj = values[0] as? MyClass {
            XCTAssert(obj === obj1)
        } else {
            XCTFail("Failed to read captured instance")
        }
        XCTAssert(values[1] is UnsafeRawPointer)

        XCTAssertEqual(m, try mirror(reflecting: makeMethod(instance: obj1)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeMethod(instance: obj2)))
        XCTAssertNotEqual(m, try mirror(reflecting: makeBuiltIn(37, "abc", 42, true)))
    }

    func testStructMethod() throws {
        let f = makeMethod(value: "abc")
        let m = try mirror(reflecting: f)
        let values = try m.capturedValues()
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values[0] as? String, "abc")

        XCTAssertEqual(m, try mirror(reflecting: makeMethod(value: "abc")))
        XCTAssertNotEqual(m, try mirror(reflecting: makeMethod(value: "xyz")))
        XCTAssertNotEqual(m, try mirror(reflecting: makeMethod(instance: MyClass(value: "abc"))))
    }

    func testSharedContext() throws {
        // Optimized case - variable is captured as if by value, but instead context is shared between two closures
        let (f1, f2) = makeSharedContext()
        var ctx: UnsafeRawPointer? = nil
        do {
            let m1 = try mirror(reflecting: f1)
            let values1 = try m1.capturedValues()
            let m2 = try mirror(reflecting: f2)
            let values2 = try m2.capturedValues()
            XCTAssertEqual(values1.count, 1)
            XCTAssertEqual(values1[0] as? [String], ["foo", "bar", "baz"])
            //XCTAssertEqual(values1[1] as? Int, 42)
            XCTAssertEqual(values2.count, 1)
            XCTAssertEqual(values2[0] as? [String], ["foo", "bar", "baz"])
            //XCTAssertEqual(values2[1] as? Int, 42)
            XCTAssertEqual(m1.context, m2.context)
            ctx = m1.context
        }
        f2()
        do {
            let m1 = try mirror(reflecting: f1)
            let values1 = try m1.capturedValues()
            let m2 = try mirror(reflecting: f2)
            let values2 = try m2.capturedValues()
            XCTAssertEqual(values1.count, 1)
            XCTAssertEqual(values1[0] as? [String], ["foo", "bar", "baz", "zop"])
            //XCTAssertEqual(values1[1] as? Int, 47)
            XCTAssertEqual(values2.count, 1)
            XCTAssertEqual(values2[0] as? [String], ["foo", "bar", "baz", "zop"])
            //XCTAssertEqual(values2[1] as? Int, 47)
            XCTAssertEqual(m1.context, m2.context)
            XCTAssertEqual(m1.context, ctx)
        }
    }

    func testByRef() throws {
        let (f1, f2) = makeByRef()
        let m1 = try mirror(reflecting: f1)
        let references1 = try m1.captureReferences()
        XCTAssertEqual(references1.count, 2)
        let r11 = references1[0]
        XCTAssertEqual(r11.value as? [String], ["foo", "bar", "baz"])
        let r12 = references1[1]
        XCTAssertEqual(r12.value as? Int, 7)
        let m2 = try mirror(reflecting: f2)
        let references2 = try m2.captureReferences()
        XCTAssertEqual(references2.count, 2)
        let r21 = references2[0]
        XCTAssertEqual(r21.value as? [String], ["foo", "bar", "baz"])
        let r22 = references2[1]
        XCTAssertEqual(r22.value as? Int, 42)
        XCTAssertEqual(r11, r21)
        XCTAssertNotEqual(r12, r22)

        XCTAssertEqual(f1(), ArrayAndInt(a: ["foo", "bar", "baz", "qux"], b: 14))
        XCTAssertEqual(r11.value as? [String], ["foo", "bar", "baz", "qux"])
        XCTAssertEqual(r12.value as? Int, 14)
        r11.value = ([] as [String])
        r12.value = 2
        XCTAssertEqual(f1(), ArrayAndInt(a: ["qux"], b: 4))

        XCTAssertEqual(f2(), ArrayAndInt(a: ["qux", "zop"], b: 47))
        XCTAssertEqual(r21.value as? [String], ["qux", "zop"])
        XCTAssertEqual(r22.value as? Int, 47)
        r21.value = ["xyz"]
        r22.value = 1
        XCTAssertEqual(f2(), ArrayAndInt(a: ["xyz", "zop"], b: 6))
    }
}
