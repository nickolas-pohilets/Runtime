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

enum RuntimeError: Error {
    case couldNotGetTypeInfo(type: Any.Type, kind: Kind)
    case couldNotGetPointer(type: Any.Type, value: Any)
    case noPropertyNamed(name: String)
    case unableToBuildType(type: Any.Type)
    case errorGettingValue(name: String, type: Any.Type)
    case unknownCallingConvention(type: Any.Type, value: Int)
    case unsupportedCallingConvention(function: Any, callingConvention: CallingConvention)
    case genericFunctionsAreNotSupported
    case unexpectedByRefLayout(type: Any.Type)
    case unexpectedGenericParam(buffer: UnsafeBufferPointer<UInt8>)
    case unexpectedMetadataSource(buffer: UnsafeBufferPointer<UInt8>)
    case failedToDemangle(type: MangledTypeName)
    case weakReferenceAmbiguity(type: Any.Type)
}
