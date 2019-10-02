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

struct FunctionMetadata: MetadataType {
    
    var pointer: UnsafeMutablePointer<FunctionMetadataLayout>
    
    func info() throws -> FunctionInfo {
        let (numberOfArguments, argumentTypes, returnType) = argumentInfo()
        return FunctionInfo(numberOfArguments: numberOfArguments,
                            argumentTypes: argumentTypes,
                            returnType: returnType,
                            throws: `throws`(),
                            isEscaping: isEscaping(),
                            callingConvention: try callingConvention())
    }
    
    private func argumentInfo() -> (Int, [Any.Type], Any.Type) {
        let n = numberArguments()
        var argTypes = pointer.pointee.argumentVector.vector(n: n + 1)
        
        let resultType = argTypes[0]
        argTypes.removeFirst()
        
        return (n, argTypes, resultType)
    }
    
    // See https://github.com/apple/swift/blob/ebcbaca9681816b9ebaa7ba31ef97729e707db93/include/swift/ABI/MetadataValues.h#L738
    private func numberArguments() -> Int {
        return pointer.pointee.flags & 0x0000FFFF
    }
    
    private func callingConvention() throws -> CallingConvention {
        let rawCC = (pointer.pointee.flags & 0x00FF0000) >> 16
        guard let cc = CallingConvention(rawValue: rawCC) else {
            throw RuntimeError.unknownCallingConvention(type: self.type, value: rawCC)
        }
        return cc
    }
    
    private func `throws`() -> Bool {
        return pointer.pointee.flags & 0x01000000 != 0
    }
    
    private func hasParamFlags() -> Bool {
        return pointer.pointee.flags & 0x02000000 != 0
    }
    
    private func isEscaping() -> Bool {
        return pointer.pointee.flags & 0x04000000 != 0
    }
}
