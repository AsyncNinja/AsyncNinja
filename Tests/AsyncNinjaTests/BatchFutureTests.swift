//
//  Copyright (c) 2016 Anton Mironov
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

class BatchFutureTests : XCTestCase {

  static let allTests = [
    ("testJoined", testJoined),
    ("testReduce", testReduce),
    ("testReduceThrows", testReduceThrows),
    ("testMapToFuture", testMapToFuture),
    ("testMapToValue", testMapToValue),
    ]

  func testJoined() {
    let value: [Int] = (1...5)
      .map { value in future(after: 1.0 - Double(value) / 5.0, block: { value }) }
      .joined()
      .wait().success!
    XCTAssertEqual([1, 2, 3, 4, 5], Set(value))
  }

  func testReduce() {
    let value: Int = (1...5)
      .map { value in future(after: Double(value) / 10.0) { value } }
      .reduce(initialResult: 5) { $0 + $1 }
      .wait().success!
    XCTAssertEqual(20, value)
  }

  func testReduceThrows() {
    let value = (1...5)
      .map { value in future(after: Double(value) / 10.0) { value } }
      .reduce(initialResult: 5) {
        if 3 == $1 { throw TestError.testCode }
        else { return $0 + $1 }
      }
      .wait()
    XCTAssertEqual(TestError.testCode, value.failure as! TestError)
  }

  func testMapToFuture() {
    let value = (1...5)
      .asyncMap(executor: .utility) { value in future(after: Double(value) / 10.0) { value } }
      .mapSuccess { $0.reduce(5, +) }
      .wait().success!
    XCTAssertEqual(20, value)
  }

  func testMapToValue() {
    let value = (1...5)
      .asyncMap(executor: .utility)  { $0 }
      .mapSuccess { $0.reduce(5) { $0 + $1 } }
      .wait().success!
    XCTAssertEqual(20, value)
  }

}
