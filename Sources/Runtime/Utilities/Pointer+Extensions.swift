// MIT License
//
// Copyright (c) 2017 Wesley Wickwire
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

extension UnsafePointer {
    
    var raw: UnsafeRawPointer {
        return UnsafeRawPointer(self)
    }
    
    var mutable: UnsafeMutablePointer<Pointee> {
        return UnsafeMutablePointer<Pointee>(mutating: self)
    }
    
    func vector(n: Int) -> [Pointee] {
        var result = [Pointee]()
        for i in 0..<n {
            result.append(advanced(by: i).pointee)
        }
        return result
    }
}

extension UnsafePointer where Pointee: Equatable {
    func advance(to value: Pointee) -> UnsafePointer<Pointee> {
        var pointer = self
        while pointer.pointee != value {
            pointer = pointer.advanced(by: 1)
        }
        return pointer
    }
}

extension UnsafeMutablePointer {
    
    var raw: UnsafeMutableRawPointer {
        return UnsafeMutableRawPointer(self)
    }
    
    func vector(n: Int) -> [Pointee] {
        var result = [Pointee]()
        for i in 0..<n {
            result.append(advanced(by: i).pointee)
        }
        return result
    }
    
    func advanced(by n: Int, wordSize: Int) -> UnsafeMutableRawPointer {
        return self.raw.advanced(by: n * wordSize)
    }
}

extension UnsafeBufferPointer where Element: Hashable, Element: ExpressibleByIntegerLiteral {
    init(nullTerminated start: UnsafePointer<Element>?) {
        if let start = start {
            let end = start.advance(to: 0)
            let count = start.distance(to: end)
            self.init(start: start, count: count)
        } else {
            self.init(start: nil, count: 0)
        }
    }
}

extension UnsafeMutableBufferPointer {
    func forEachPointer<T>(_ block: (UnsafeMutablePointer<Element>) throws -> T) rethrows -> [T] {
        var buffer = self
        var res: [T] = []
        while !buffer.isEmpty {
            res.append(try block(buffer.baseAddress!))
            buffer = UnsafeMutableBufferPointer(rebasing: buffer.dropFirst())
        }
        return res
    }
}
