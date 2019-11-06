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

enum SpecialProtocol: UInt8 {
    /// Not a special protocol.
    ///
    /// This must be 0 for ABI compatibility with Objective-C protocol_t records.
    case none = 0

    /// The Error protocol.
    case error = 1
}

struct ExistentialTypeFlags {
    private var data: UInt32

    var numWitnessTable: Int {
        return Int(data & 0x00FFFFFF)
    }

    var canBeStruct: Bool {
        return data & 0x80000000 != 0
    }

    var hasSuperclass: Bool {
        return data & 0x40000000 != 0
    }

    var specialProtocol: SpecialProtocol? {
        return SpecialProtocol(rawValue: UInt8((data & 0x3F000000) >> 24))
    }
}

struct ProtocolMetadataLayout: MetadataLayoutType {
    var _kind: Int
    var flags: ExistentialTypeFlags
    var numberOfProtocols: Int
    var protocolDescriptorVector: UnsafeMutablePointer<ProtocolDescriptor>
}
