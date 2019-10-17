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

fileprivate protocol Foo {
    associatedtype Result
    func frimble() -> Self
    func bromble() -> Result
}

fileprivate class GenericClass<T: Foo, U: Foo> where T.Result == U.Result, T.Result: Hashable {
    let a: T
    let b: U

    init(a: T, b: U) {
        self.a = a
        self.b = b
    }

    func check() -> Bool {
        return a.frimble().bromble() == b.bromble()
    }
}

fileprivate struct GenericStruct<T: Foo & Hashable, U: Hashable> : Hashable {
    var x: T
    var y: U
}

fileprivate struct Z: Foo, Hashable {
    var value: String

    func frimble() -> Z {
        return self
    }
    func bromble() -> Int {
        return value.count
    }
}

fileprivate struct Outer<T, U> {
    struct Middle<P, Q, R, S> {
        struct Inner<X, Y, Z> {
            func makeFunc(a: U, b: R, c: Z) -> () -> Void {
                let ax = [a]
                let bx = [b]
                let cx = [c]
                return { print(ax, bx, cx) }
            }
        }
    }
}

private extension Hashable {
    func makeGeneric() -> () -> Void {
        return { print(self) }
    }
}

private class GenericProvider<T: Hashable> {
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

class FunctionMirrorGenericTests: XCTestCase {
    private func makeCaptureValuesOfManyTypes<X: Hashable, Y: Hashable, Z: Hashable>(x: X, y: Y, z: Z) -> () -> Void {
        return { print(x, y, z) }
    }

    private func makeCaptureMiscSpecializedGenerics<T: Foo & Hashable>(x: T) -> () -> Void where T.Result: Hashable {
        let a: [T] = [x, x]
        let b: T? = nil
//        let c: GenericClass<T, T> = GenericClass(a: x, b: x)
        let d: GenericStruct<T, T> = GenericStruct(x: x, y: x)
        return { print(x, a, b as Any, d) }
    }

    private func makeCaptureGenericType<T: DefaultConstructor>(type: T.Type) -> () -> Void {
        let x: [T] = []
        let y: T = T()
        return { print(type, x, y) }
    }

    private func makeGenericByRef<T>(x: T, y: T) -> () -> Any {
        var acc = x;
        return {
            if arc4random() % 2 == 0 {
                acc = y;
            }
            return acc
        }
    }

    func testCaptureValuesOfManyTypes() throws {
        let f = makeCaptureValuesOfManyTypes(x: 42, y: "abc", z: (nil as ObjectIdentifier?))
        let m = try mirror(reflecting: f)
        XCTAssertEqual(m.capturedValues.count, 3)
        let xm = m.capturedValues[0] as! ByRefMirror
        XCTAssertEqual(try xm.value() as? Int, 42)
        let ym = m.capturedValues[1] as! ByRefMirror
        XCTAssertEqual(try ym.value() as? String, "abc")
        let zm = m.capturedValues[2] as! ByRefMirror
        XCTAssertEqual(cast(try zm.value(), to: ObjectIdentifier?.self), ObjectIdentifier??.some(nil))
    }

    func testCaptureMiscSpecializedGenerics() throws {
        let x = Z(value: "abc")
        let f = makeCaptureMiscSpecializedGenerics(x: x)
        let m = try mirror(reflecting: f)
        XCTAssertEqual(m.capturedValues.count, 4)
        XCTAssertEqual(try? (m.capturedValues[0] as? ByRefMirror)?.value() as? Z, x)
        XCTAssertEqual(m.capturedValues[1] as? [Z], [x, x])
        XCTAssertEqual(cast(try (m.capturedValues[2] as! ByRefMirror).value(), to: Z?.self), Z??.some(nil))
        XCTAssertEqual(try? (m.capturedValues[3] as? ByRefMirror)?.value() as? GenericStruct<Z, Z>, GenericStruct(x: x, y: x))
    }

    func testCaptureDeepGenerics() throws {
        typealias A = Outer<Bool, String>
        typealias B = A.Middle<[String], Double?, FunctionMirrorGenericTests, Data>
        typealias C = B.Inner<Mirror, SIMD4<Float>, IndexSet>
        let f = C().makeFunc(a: "abc", b: self, c: IndexSet(integersIn: 0..<10))
        let m = try mirror(reflecting: f)
        XCTAssertEqual(m.capturedValues.count, 3)
    }

    func testWIP() throws {
////        let g = makeGenericStruct(x: [s], y: s)
////        let ti = try typeInfo(of: type(of: g))
////        print(ti)
//
//        // Case 1
//        //  types:
//        //    "xz_x_q_SHRzSHR_r0_lXX"
//        //    "q_z_x_q_SHRzSHR_r0_lXX"
//        //  sources:
//        //    "x" -> B0
//        //    "q_" -> B1
//        //let f = makeGeneric(x: [s], y: s)
//
//        // Case 2:
//        //  types:
//        //    "xz_x_SHRzlXX"
//        //    "SayxG"
//        //    "xSgz_x_SHRzlXX"
//        //  sources:
//        //    "x" -> B0
//        //let f = makeGeneric2(x: s)
//
//        // Case 3:
//        //  types:
//        //     "xz_x_SHRzlXX"
//        //  sources:
//        //     "x" -> "B0"
//        // let f = s.makeGeneric()
//
//        // Case 4:
//        //  types:
//        //    {01:0xfffffe84800000d0}yxG
//        //    xz_x_SHRzlXX
//        //  sources:
//        //     "x" -> "G0R0_"
//        //     no bindings
//        //let f = GenericProvider<String>(x: "abc").makeGeneric("xyz")
//
//        //  'B' -> ClosureBinding
//        //  'R' -> ReferenceCapture
//        //  'M' -> MetadataCapture
//        //  'G' -> GenericArgument
//        //  'S' -> Self
//        //let f = makeGenericMD(type: MyStruct.self)
//        let f = makeGenericByRef(x: 0xaaaaaaaaaaaa, y: 0xbbbbbbbbbbbb)
//        let m = try mirror(reflecting: f)
//        XCTAssertEqual(m.capturedValues.count, 2)
//        do {
//            let xm = m.capturedValues[0] as! ByRefMirror
//            let v = try xm.value()
//            print(v)
//        }
//        do {
//            let ym = m.capturedValues[1] as! ByRefMirror
//            let v = try ym.value()
//            print(v)
//        }
//        XCTAssertEqual(m.capturedValues[0] as? [MyStruct], [s])
//        XCTAssertEqual(m.capturedValues[1] as? MyStruct, s)
    }

    func testMetadataSource() {
        XCTAssertEqual(try MetadataSource(string: "B1"), MetadataSource.closureBinding(index: 1))
        XCTAssertEqual(try MetadataSource(string: "R0"), MetadataSource.referenceCapture(index: 0))
        XCTAssertEqual(try MetadataSource(string: "M106"), MetadataSource.metadataCapture(index: 106))
        XCTAssertEqual(try MetadataSource(string: "G0R1_"), MetadataSource.genericArgument(index: 0, base: .referenceCapture(index: 1)))
        XCTAssertEqual(try MetadataSource(string: "S"), MetadataSource.`self`)
    }

    func testGenericParams() throws {
        XCTAssertEqual(try GenericParam(typeName: "x"), GenericParam(depth: 0, index: 0))
        XCTAssertEqual(try GenericParam(typeName: "qz"), GenericParam(depth: 0, index: 0))
        XCTAssertEqual(try GenericParam(typeName: "q_"), GenericParam(depth: 0, index: 1))
        XCTAssertEqual(try GenericParam(typeName: "qd__"), GenericParam(depth: 1, index: 0))
        XCTAssertEqual(try GenericParam(typeName: "qd_0_"), GenericParam(depth: 1, index: 1))
        XCTAssertEqual(try GenericParam(typeName: "qd_1_"), GenericParam(depth: 1, index: 2))
        XCTAssertEqual(try GenericParam(typeName: "qd_2_"), GenericParam(depth: 1, index: 3))
        XCTAssertEqual(try GenericParam(typeName: "qd0__"), GenericParam(depth: 2, index: 0))
        XCTAssertEqual(try GenericParam(typeName: "qd0_0_"), GenericParam(depth: 2, index: 1))
        XCTAssertEqual(try GenericParam(typeName: "qd0_1_"), GenericParam(depth: 2, index: 2))
    }
}
