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
import XCTest
@testable import Runtime
import ObjectiveC.runtime

fileprivate protocol Foo {
    func foo()
}

fileprivate protocol Bar {
    func bar()
}

fileprivate struct HashableStruct: Hashable, Foo, Bar {
    var a: Int
    var b: String

    func foo() {}
    func bar() {}
}

fileprivate struct NonHashableStruct: Foo, Bar {
    var a: Int
    var b: String

    func foo() {}
    func bar() {}
}

fileprivate class HashableClass: Hashable, Foo, Bar {
    var value: String
    init(value: String) { self.value = value }

    static func == (lhs: HashableClass, rhs: HashableClass) -> Bool {
        return lhs.value == rhs.value
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.value)
    }

    func foo() {}
    func bar() {}
}

fileprivate class NonHashableClass: Foo, Bar {
    var value: String
    init(value: String) { self.value = value }

    func foo() {}
    func bar() {}
}

fileprivate class Derived1: HashableClass {}
fileprivate class Derived2: HashableClass {}
fileprivate class Derived1A: Derived1 {}
fileprivate class Derived1B: Derived1 {}

@objc
fileprivate class ObjCClass: NSObject {
    var value: String
    init(value: String) { self.value = value }

    override func isEqual(_ object: Any?) -> Bool {
        return self.value == (object as? ObjCClass)?.value
    }

    override var hash: Int {
        return self.value.hashValue
    }
}

@objc
fileprivate class ObjCDerived1: ObjCClass {}

@objc
fileprivate class ObjCDerived2: ObjCClass {}

@objc
fileprivate class ObjCDerived1A: ObjCDerived1 {}

@objc
fileprivate class ObjCDerived1B: ObjCDerived1 {}



class EqualityStrategyTests: XCTestCase {

    static var allTests: [(String, (ValueWitnessTableTests) -> () throws -> Void)] {
        return [
        ]
    }

    func verifyEqual<T>(_ lhs: T, _ rhs: T) {
        XCTAssertTrue(try EqualityStrategy.areEqual(lhs, rhs), "Expected: \(lhs) == \(rhs) (\(T.self))")
    }

    func verifyNonEqual<T>(_ lhs: T, _ rhs: T) {
        XCTAssertFalse(try EqualityStrategy.areEqual(lhs, rhs), "Expected: \(lhs) != \(rhs) (\(T.self))")
    }

    func verifyMany<T>(_ eq: [T], _ nonEqual: [T]) {
        if eq.count == 1 {
            verifyEqual(eq[0], eq[0])
        } else {
            for lhs in eq {
                for rhs in eq {
                    verifyEqual(lhs, rhs)
                }
            }
        }

        for lhs in eq {
            for rhs in nonEqual {
                verifyNonEqual(lhs, rhs)
            }
        }
    }

    func verify<T>(_ a: T, _ b: T) {
        verifyMany([a], [b])
    }

    func testBuiltIn() {
        verify(42, 37)
        verify("abc", "xyz")
        verify(true, false)
    }

    func testHashableStruct() {
        verifyMany([
            HashableStruct(a: 42, b: "abc")
        ], [
            HashableStruct(a: 37, b: "abc"),
            HashableStruct(a: 42, b: "xyz")
        ])
    }

    func testNonHashableStruct() throws {
        let a = NonHashableStruct(a: 42, b: "abc")
        switch try EqualityStrategy(type: NonHashableStruct.self) {
        case .none:
            do {}
        default:
            XCTFail("EqualityStrategy for NonHashableStruct should be .none")
        }
        XCTAssertEqual(try EqualityStrategy.areEqual(a, a), false)
    }

    func testHashableClass() {
        verifyMany([HashableClass(value: "abc"), HashableClass(value: "abc")], [HashableClass(value: "xyz")])
    }

    func testNonHashableClass() {
        verify(NonHashableClass(value: "abc"), NonHashableClass(value: "abc"))
    }

    @inline(never)
    private func makeFunc(_ x: Int) -> () -> Int {
        return { x * x }
    }

    @inline(never)
    private func makeFuncAsArr(_ x: Int) -> [() -> Int] {
        // Packing function into array causes creation of the reabsatraction thunk
        // Pack function into array inside the function to prevent multiple distinct reabstraction thunks being created in the caller
        return [makeFunc(x)]
    }

    private typealias TestTuple = (Bool, () -> Int, HashableStruct, NonHashableClass)

    @inline(never)
    private func makeTupleAsArr(_ x: TestTuple) -> [TestTuple] {
        return [x]
    }

    func testFunction() {
        verifyMany(makeFuncAsArr(1) + makeFuncAsArr(1), makeFuncAsArr(2))
    }

    func testTuple() {
        let obj = NonHashableClass(value: "abc")
        verifyMany(
            makeTupleAsArr((true, makeFunc(1), HashableStruct(a: 42, b: "abc"), obj)) +
            makeTupleAsArr((true, makeFunc(1), HashableStruct(a: 42, b: "abc"), obj)),
            // --
            makeTupleAsArr((false, makeFunc(1), HashableStruct(a: 42, b: "abc"), obj)) +
            makeTupleAsArr((true, makeFunc(2), HashableStruct(a: 42, b: "abc"), obj)) +
            makeTupleAsArr((true, makeFunc(1), HashableStruct(a: 42, b: "xyz"), obj)) +
            makeTupleAsArr((true, makeFunc(1), HashableStruct(a: 42, b: "xyz"), NonHashableClass(value: "abc")))
        )
    }

    func testAny() {
        verify(42 as Any, "42" as Any)
    }

    func testProtocol() {
        let obj: Foo = NonHashableClass(value: "abc")
        verifyMany([
            HashableStruct(a: 42, b: "abc") as Foo,
            HashableStruct(a: 42, b: "abc") as Foo,
        ], [
            HashableStruct(a: 37, b: "xyz") as Foo,
            HashableClass(value: "abc") as Foo,
            obj as Foo
        ])
        verifyMany([
            HashableClass(value: "abc") as Foo,
            HashableClass(value: "abc") as Foo,
        ], [
            HashableStruct(a: 37, b: "xyz") as Foo,
            HashableClass(value: "xyz") as Foo,
            obj as Foo
        ])
        verifyMany([
            obj,
            obj
        ], [
            HashableStruct(a: 37, b: "abc") as Foo,
            HashableClass(value: "abc") as Foo,
            NonHashableClass(value: "abc") as Foo
        ])
    }

    func testSeveralProtocols() {
        let obj: Foo & Bar = NonHashableClass(value: "abc")
        verifyMany([
            HashableStruct(a: 42, b: "abc") as Foo & Bar,
            HashableStruct(a: 42, b: "abc") as Foo & Bar,
        ], [
            HashableStruct(a: 37, b: "xyz") as Foo & Bar,
            HashableClass(value: "abc") as Foo & Bar,
            obj as Foo & Bar
        ])
        verifyMany([
            HashableClass(value: "abc") as Foo & Bar,
            HashableClass(value: "abc") as Foo & Bar,
        ], [
            HashableStruct(a: 37, b: "xyz") as Foo & Bar,
            HashableClass(value: "xyz") as Foo & Bar,
            obj as Foo & Bar
        ])
        verifyMany([
            obj,
            obj
        ], [
            HashableStruct(a: 37, b: "abc") as Foo & Bar,
            HashableClass(value: "abc") as Foo & Bar,
            NonHashableClass(value: "abc") as Foo & Bar
        ])
    }

    func testMetatype() {
        verify(String.self as Any.Type, Int.self as Any.Type)
        verify(HashableClass.self as AnyClass, NonHashableClass.self as AnyClass)
        verify(HashableStruct.self as (Any & Foo).Type, NonHashableStruct.self as (Any & Foo).Type)
        verify(HashableClass.self as (Any & Foo).Type, NonHashableClass.self as (Any & Foo).Type)
        verify(HashableClass.self as (AnyObject & Foo).Type, NonHashableClass.self as (AnyObject & Foo).Type)
        verify(HashableStruct.self as (Any & Foo & Bar).Type, NonHashableStruct.self as (Any & Foo & Bar).Type)
        verify(HashableClass.self as (Any & Foo & Bar).Type, NonHashableClass.self as (Any & Foo & Bar).Type)
        verify(HashableClass.self as (AnyObject & Foo & Bar).Type, NonHashableClass.self as (AnyObject & Foo & Bar).Type)
        verify(NSString.self, NSMutableString.self)
        verify(NSCopying.self as Protocol, NSMutableCopying.self as Protocol)
    }

    func testObjCBridgableClass() {
        verifyMany([
            "abc" as NSString,
            ("a" as NSString).appending("bc") as NSString,
            "abc" as NSMutableString,
        ], [
            "xyz" as NSString
        ])
    }

    func testObjCBridgableNSObjectProtocol() {
        verifyMany([
            "abc" as NSString as NSObjectProtocol,
            ("a" as NSString).appending("bc") as NSString as NSObjectProtocol,
            "abc" as NSMutableString as NSObjectProtocol,
        ], [
            "xyz" as NSString as NSObjectProtocol
        ])
    }

    func testObjCClass() {
        verifyMany([
            ObjCClass(value: "abc"),
            ObjCDerived1(value: "abc") as ObjCClass,
            ObjCDerived2(value: "abc") as ObjCClass,
        ], [
            ObjCClass(value: "xyz"),
            ObjCDerived1(value: "xyz") as ObjCClass,
            ObjCDerived2(value: "xyz") as ObjCClass,
        ])

        verifyMany([
            ObjCDerived1(value: "abc"),
            ObjCDerived1A(value: "abc") as ObjCClass,
            ObjCDerived1B(value: "abc") as ObjCClass,
        ], [
            ObjCDerived1(value: "xyz"),
            ObjCDerived1A(value: "xyz") as ObjCClass,
            ObjCDerived1B(value: "xyz") as ObjCClass,
        ])
    }

    func testNSObjectProtocol() {
        verifyMany([
            ObjCClass(value: "abc") as NSObjectProtocol,
            ObjCDerived1(value: "abc") as NSObjectProtocol,
            ObjCDerived2(value: "abc") as NSObjectProtocol,
        ], [
            ObjCClass(value: "xyz") as NSObjectProtocol,
            ObjCDerived1(value: "xyz") as NSObjectProtocol,
            ObjCDerived2(value: "xyz") as NSObjectProtocol,
        ])

        verifyMany([
            ObjCDerived1(value: "abc") as NSObjectProtocol,
            ObjCDerived1A(value: "abc") as NSObjectProtocol,
            ObjCDerived1B(value: "abc") as NSObjectProtocol,
        ], [
            ObjCDerived1(value: "xyz") as NSObjectProtocol,
            ObjCDerived1A(value: "xyz") as NSObjectProtocol,
            ObjCDerived1B(value: "xyz") as NSObjectProtocol,
        ])
    }
}
