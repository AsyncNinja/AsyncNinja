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

class BatchFutureTests: XCTestCase {

  static let allTests = [
    ("testJoined", testJoined),
    ("testEmptyJoined", testEmptyJoined),
    ("testReduce", testReduce),
    ("testEmptyReduce", testEmptyReduce),
    ("testReduceThrows", testReduceThrows),
    ("testFlatMap", testFlatMap),
    ("testEmptyFlatMap", testEmptyFlatMap),
    ("testMap", testMap),
    ("testEmptyMap", testEmptyMap)
    ]

  func testJoined() {
    let value: [Int] = (1...5)
      .map { value in future(after: 1.0 - Double(value) / 5.0, { value }) }
      .joined()
      .wait().success!
    XCTAssertEqual([1, 2, 3, 4, 5], Set(value))
  }

  func testEmptyJoined() {
    let value: [Int] = [Int]()
      .map { value in future(after: 1.0 - Double(value) / 5.0, { value }) }
      .joined()
      .wait().success!
    XCTAssertEqual([], Set(value))
  }

  func testReduce() {
    func asyncTransform(value: Int) -> Future<Int> {
        return future(after: Double(value) / 10.0) { value }
    }

    let value: Int = (1...5)
      .map(asyncTransform)
      .asyncReduce(5, +)
      .wait().success!
    XCTAssertEqual(20, value)
  }

  func testEmptyReduce() {
    func asyncTransform(value: Int) -> Future<Int> {
      return future(after: Double(value) / 10.0) { value }
    }

    let value: Int = [Int]()
      .map(asyncTransform)
      .asyncReduce(5) { $0 + $1 }
      .wait().success!
    XCTAssertEqual(5, value)
  }

  func testReduceThrows() {
    func asyncTransform(value: Int) -> Future<Int> {
        return future(after: Double(value) / 10.0) { value }
    }

    let value = (1...5)
      .map(asyncTransform)
      .asyncReduce(5) {
        if 3 == $1 {
          throw TestError.testCode
        } else {
          return $0 + $1
        }
      }
      .wait()
    XCTAssertEqual(TestError.testCode, value.failure as! TestError)
  }

  func testFlatMap() {
    let expectation = self.expectation(description: "finish")

    let fixture = (1...10).map { _ in pickInt() }
    let sum = fixture.reduce(0, +)

    fixture
      .asyncFlatMap { value in future(after: Double(value) / 200.0) { value } }
      .map { $0.reduce(0, +) }
      .onSuccess {
        XCTAssertEqual(sum, $0)
        expectation.fulfill()
      }

    self.waitForExpectations(timeout: 10.0, handler: nil)
  }

  func testEmptyFlatMap() {
    let expectation = self.expectation(description: "finish")

    let fixture = [Int]().map { _ in pickInt() }
    let sum = fixture.reduce(0, +)

    fixture
      .asyncFlatMap { value in future(after: Double(value) / 200.0) { value } }
      .map { $0.reduce(0, +) }
      .onSuccess { (value) in
        XCTAssertEqual(sum, value)
        expectation.fulfill()
    }

    self.waitForExpectations(timeout: 10.0, handler: nil)
  }

  func testMap() {
    let value = (1...5)
      .asyncMap(executor: .utility) { $0 }
      .map { $0.reduce(5) { $0 + $1 } }
      .wait().success!
    XCTAssertEqual(20, value)
  }

  func testEmptyMap() {
    let value = [Int]()
      .asyncMap(executor: .utility) { $0 }
      .map { $0.reduce(5) { $0 + $1 } }
      .wait().success!
    XCTAssertEqual(5, value)
  }

}
