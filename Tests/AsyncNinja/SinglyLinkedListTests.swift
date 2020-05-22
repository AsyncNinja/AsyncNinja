//
//  Copyright (c) 2016-2017 Anton Mironov
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom
//  the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
//

import XCTest
import Dispatch
@testable import AsyncNinja
#if os(Linux)
  import Glibc
#endif

class SinglyLinkedListTests: XCTestCase {
  static let allTests = [
    ("testQueue", testQueue),
    ("testStack", testStack)
  ]

  func testQueue() {
    var queue = Queue<Int>()
    XCTAssertNil(queue.first)
    XCTAssertNil(queue.last)
    XCTAssertNil(queue.pop())
    XCTAssertEqual(0, queue.count)

    let valueA = 1
    queue.push(valueA)
    XCTAssertEqual(valueA, queue.first)
    XCTAssertEqual(valueA, queue.last)
    XCTAssertEqual(1, queue.count)
    let queueA = queue
    XCTAssertEqual(valueA, queue.pop())

    XCTAssertNil(queue.first)
    XCTAssertNil(queue.last)
    XCTAssertEqual(0, queue.count)
    XCTAssertNil(queue.pop())
    XCTAssertEqual(1, queueA.count)

    let valueB = 2
    queue.push(valueB)
    XCTAssertEqual(valueB, queue.first)
    XCTAssertEqual(valueB, queue.last)
    XCTAssertEqual(1, queue.count)

    let valueC = 3
    queue.push(valueC)
    XCTAssertEqual(valueB, queue.first)
    XCTAssertEqual(valueC, queue.last)
    XCTAssertEqual(2, queue.count)

    let valueD = 4
    queue.push(valueD)
    XCTAssertEqual(valueB, queue.first)
    XCTAssertEqual(valueD, queue.last)
    XCTAssertEqual(3, queue.count)

    XCTAssertEqual(valueB, queue.pop())
    XCTAssertEqual(valueC, queue.first)
    XCTAssertEqual(valueD, queue.last)
    XCTAssertEqual(2, queue.count)

    XCTAssertEqual(valueC, queue.pop())
    XCTAssertEqual(valueD, queue.first)
    XCTAssertEqual(valueD, queue.last)
    XCTAssertEqual(1, queue.count)

    XCTAssertEqual(valueD, queue.pop())
    XCTAssertNil(queue.first)
    XCTAssertNil(queue.last)
    XCTAssertEqual(0, queue.count)
    XCTAssertNil(queue.pop())
    XCTAssertEqual(0, queue.count)
  }

  func testStack() {
    var stack = Stack<Int>()
    XCTAssertNil(stack.first)
    XCTAssertNil(stack.last)
    XCTAssertNil(stack.pop())
    XCTAssertEqual(0, stack.count)

    let valueA = 1
    stack.push(valueA)
    XCTAssertEqual(valueA, stack.first)
    XCTAssertEqual(valueA, stack.last)
    XCTAssertEqual(1, stack.count)
    XCTAssertEqual(valueA, stack.pop())

    XCTAssertNil(stack.first)
    XCTAssertNil(stack.last)
    XCTAssertEqual(0, stack.count)
    XCTAssertNil(stack.pop())

    let valueB = 2
    stack.push(valueB)
    XCTAssertEqual(valueB, stack.first)
    XCTAssertEqual(valueB, stack.last)
    XCTAssertEqual(1, stack.count)

    let valueC = 3
    stack.push(valueC)
    XCTAssertEqual(valueC, stack.first)
    XCTAssertEqual(valueB, stack.last)
    XCTAssertEqual(2, stack.count)

    let valueD = 4
    stack.push(valueD)
    XCTAssertEqual(valueD, stack.first)
    XCTAssertEqual(valueB, stack.last)
    XCTAssertEqual(3, stack.count)

    XCTAssertEqual(valueD, stack.pop())
    XCTAssertEqual(valueC, stack.first)
    XCTAssertEqual(valueB, stack.last)
    XCTAssertEqual(2, stack.count)

    XCTAssertEqual(valueC, stack.pop())
    XCTAssertEqual(valueB, stack.first)
    XCTAssertEqual(valueB, stack.last)
    XCTAssertEqual(1, stack.count)

    XCTAssertEqual(valueB, stack.pop())
    XCTAssertNil(stack.first)
    XCTAssertNil(stack.last)
    XCTAssertEqual(0, stack.count)
    XCTAssertNil(stack.pop())
    XCTAssertEqual(0, stack.count)
  }
}
