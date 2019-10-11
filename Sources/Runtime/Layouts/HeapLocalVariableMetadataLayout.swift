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

struct HeapLocalVariableMetadataLayout: MetadataLayoutType {
    var _kind: Int
    var offsetToFirstCapture: UInt32
    var captureDescription: UnsafeMutablePointer<CaptureDescriptor>
}

struct CaptureDescriptor {
    /// The number of captures in the closure and the number of typerefs that
    /// immediately follow this struct.
    var numCaptureTypes: UInt32
    
    /// The number of sources of metadata available in the MetadataSourceMap
    /// directly following the list of capture's typerefs.
    var numMetadataSources: UInt32
    
    /// The number of items in the NecessaryBindings structure at the head of
    /// the closure.
    var numBindings: UInt32
    
    mutating func captureTypeRecordBuffer() -> UnsafeMutableBufferPointer<CaptureTypeRecord> {
        let n = Int(numCaptureTypes)
        return withUnsafePointer(to: &self) { (ptr: UnsafePointer<CaptureDescriptor>) in
            let start = ptr.advanced(by: 1).raw.assumingMemoryBound(to: CaptureTypeRecord.self)
            return UnsafeMutableBufferPointer(start: start.mutable, count: n)
        }
    }

    mutating func metadataSourceRecordBuffer() -> UnsafeMutableBufferPointer<MetadataSourceRecord> {
        let captureBuffer = self.captureTypeRecordBuffer()
        let captureEnd = captureBuffer.baseAddress!.advanced(by: captureBuffer.count)
        let base = captureEnd.raw.assumingMemoryBound(to: MetadataSourceRecord.self)
        return UnsafeMutableBufferPointer(start: base, count: Int(self.numMetadataSources))
    }
}

struct CaptureTypeRecord {
    var mangledTypeName: RelativePointer<Int32, UInt8>
}

struct MetadataSourceRecord {
    var mangledTypeName: RelativePointer<Int32, UInt8>
    var mangledMetadataSource: RelativePointer<Int32, UInt8>
}
