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

class BatchFutureTests : XCTestCase {

  enum TestError : Error {
    case testCode
  }

  func testJoined() {
    let value: [Int] = (1...5)
      .map { value in future(after: 1.0 - TimeInterval(value) / 5.0, block: { value }) }
      .joined()
      .wait()
    XCTAssertEqual([1, 2, 3, 4, 5], Set(value))
  }

  func testReduce() {
    let value: Int = (1...5)
      .map { value in future(after: TimeInterval(value) / 10.0) { value } }
      .reduce(initialResult: 5) { $0 + $1 }
      .wait()
    XCTAssertEqual(20, value)
  }

  func testReduceThrows() {
    let value = (1...5)
      .map { value in future(after: TimeInterval(value) / 10.0) { value } }
      .reduce(initialResult: 5) {
        if 3 == $1 { throw TestError.testCode }
        else { return $0 + $1 }
      }
      .wait()
    XCTAssertEqual(TestError.testCode, value.failureValue as! TestError)
  }

  func testMapToFuture() {
    let value = (1...5)
      .asyncMap(executor: .utility) { value in future(after: TimeInterval(value) / 10.0) { value } }
      .map { $0.reduce(5, +) }
      .wait()
    XCTAssertEqual(20, value)
  }

  func testMapToValue() {
    let value = (1...5)
      .asyncMap(executor: .utility)  { $0 }
      .map { $0.reduce(5) { $0 + $1 } }
      .wait()
    XCTAssertEqual(20, value)
  }

}
