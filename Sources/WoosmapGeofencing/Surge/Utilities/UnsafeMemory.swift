// Copyright © 2014-2019 the Surge contributors
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

/// Memory region.
struct UnsafeMemory<Element>: Sequence {
    /// Pointer to the first element
    var pointer: UnsafePointer<Element>

    /// Pointer stride between elements
    var stride: Int

    /// Number of elements
    var count: Int

    init(pointer: UnsafePointer<Element>, stride: Int = 1, count: Int) {
        self.pointer = pointer
        self.stride = stride
        self.count = count
    }

    func makeIterator() -> UnsafeMemoryIterator<Element> {
        return UnsafeMemoryIterator(self)
    }
}

struct UnsafeMemoryIterator<Element>: IteratorProtocol {
    let base: UnsafeMemory<Element>
    var index: Int?

    init(_ base: UnsafeMemory<Element>) {
        self.base = base
    }

    mutating func next() -> Element? {
        let newIndex: Int
        if let index = index {
            newIndex = index + 1
        } else {
            newIndex = 0
        }

        if newIndex >= base.count {
            return nil
        }

        self.index = newIndex
        return base.pointer[newIndex * base.stride]
    }
}

/// Protocol for collections that can be accessed via `UnsafeMemory`
protocol UnsafeMemoryAccessible: Collection {
    func withUnsafeMemory<Result>(_ body: (UnsafeMemory<Element>) throws -> Result) rethrows -> Result
}

func withUnsafeMemory<L, Result>(_ lhs: L, _ body: (UnsafeMemory<L.Element>) throws -> Result) rethrows -> Result where L: UnsafeMemoryAccessible {
    return try lhs.withUnsafeMemory(body)
}

func withUnsafeMemory<L, R, Result>(_ lhs: L, _ rhs: R, _ body: (UnsafeMemory<L.Element>, UnsafeMemory<R.Element>) throws -> Result) rethrows -> Result where L: UnsafeMemoryAccessible, R: UnsafeMemoryAccessible {
    return try lhs.withUnsafeMemory { lhsMemory in
        try rhs.withUnsafeMemory { rhsMemory in
            try body(lhsMemory, rhsMemory)
        }
    }
}
