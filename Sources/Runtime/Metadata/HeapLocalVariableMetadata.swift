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
import CRuntime

struct HeapLocalVariableMetadata {
    var pointer: UnsafeMutablePointer<HeapLocalVariableMetadataLayout>
    init(type: Any.Type) {
        self.pointer = unsafeBitCast(type, to: UnsafeMutablePointer<HeapLocalVariableMetadataLayout>.self)
    }
    
    var type: Any.Type {
        return unsafeBitCast(pointer, to: Any.Type.self)
    }
    
    var kind: Kind {
        return Kind(flag: pointer.pointee._kind)
    }

    var offsetToFirstCapture: Int {
        return Int(pointer.pointee.offsetToFirstCapture)
    }

    var numBindings: Int {
        return Int(pointer.pointee.captureDescription.pointee.numBindings)
    }

    func capturedTypes() -> [MangledTypeName] {
        let buffer = self.pointer.pointee.captureDescription.pointee.captureTypeRecordBuffer()
        return buffer.forEachPointer {
            MangledTypeName($0.pointee.mangledTypeName.advanced())
        }
    }

    func metadataSources() throws -> [(GenericParam, MetadataSource)] {
        let buffer = self.pointer.pointee.captureDescription.pointee.metadataSourceRecordBuffer()
        return try buffer.forEachPointer {
            let type = MangledTypeName($0.pointee.mangledTypeName.advanced())
            let param = try GenericParam(typeName: type)
            let encodedSource = $0.pointee.mangledMetadataSource.advanced()
            let source = try MetadataSource(buffer: UnsafeBufferPointer(nullTerminated: encodedSource))
            return (param, source)
        }
    }
    
    func types() throws -> [Any.Type] {
        let sources = try self.metadataSources()
        print(sources)
        let types = self.capturedTypes()
        print(types.description)
        return try types.map {
            return try $0.type(genericContext: nil, genericArguments: nil)
        }
    }

    func fields() throws -> [(Int, Any.Type)] {
        var offset = self.offsetToFirstCapture
        offset += MemoryLayout<Any.Type>.size * Int(self.numBindings)

        var res: [(Int, Any.Type)] = []
        for type in try self.types() {
            var effectiveType = type
            if Kind(type: type) == .opaque {
                effectiveType = ByRefMirror.self
            }
            let info = try metadata(of: effectiveType)
            let alignedOffset = (offset + info.alignment - 1) & ~(info.alignment - 1)
            res.append((alignedOffset, effectiveType))
            offset = alignedOffset + info.size
        }
        return res
    }
}
