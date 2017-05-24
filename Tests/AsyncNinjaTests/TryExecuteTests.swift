//
//  Copyright (c) 2017 Anton Mironov
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

class TryExecuteTests: XCTestCase {
  static let allTests = [
    ("testTryExecuteUntilToTheFirst", testTryExecuteUntilToTheFirst),
    ("testTryExecuteUntilToTheLast", testTryExecuteUntilToTheLast),
    ("testTryFlatExecuteUntilToTheFirst", testTryFlatExecuteUntilToTheFirst),
    ("testTryFlatExecuteUntilToTheLast", testTryFlatExecuteUntilToTheLast),
    ("testTryExecuteTimesSuccess", testTryExecuteTimesSuccess),
    ("testTryExecuteTimesFailure", testTryExecuteTimesFailure),
    ("testTryFlatExecuteTimesSuccess", testTryFlatExecuteTimesSuccess),
    ("testTryFlatExecuteTimesFailure", testTryFlatExecuteTimesFailure)
    ]

  // MARK: - try execute until

  func testTryExecuteUntilToTheFirst() {
    var items = [1, 2, 3, 4, 5]
    func validate(completion: Fallible<String>) -> Bool { return true }

    let result = tryExecute(validate: validate) {
      items.removeLast()
      return "hello"
      }
      .wait()
      .success
    XCTAssertEqual(result, "hello")
    XCTAssertEqual(items, [1, 2, 3, 4])
  }

  func testTryExecuteUntilToTheLast() {
    var items = [1, 2, 3, 4, 5]
    func validate(completion: Fallible<String>) -> Bool { return items.isEmpty }

    let result = tryExecute(validate: validate) {
      items.removeLast()
      return "hello"
      }
      .wait()
      .success
    XCTAssertEqual(result, "hello")
    XCTAssertEqual(items, [])
  }

  // MARK: - try flat execute until

  func testTryFlatExecuteUntilToTheFirst() {
    var items = [1, 2, 3, 4, 5]
    func validate(completion: Fallible<String>) -> Bool { return true }

    let result = tryFlatExecute(validate: validate) { future(after: 0.1) {
      items.removeLast()
      return "hello" } }
      .wait()
      .success
    XCTAssertEqual(result, "hello")
    XCTAssertEqual(items, [1, 2, 3, 4])
  }

  func testTryFlatExecuteUntilToTheLast() {
    var items = [1, 2, 3, 4, 5]
    func validate(completion: Fallible<String>) -> Bool { return items.isEmpty }

    let result = tryFlatExecute(validate: validate) { future(after: 0.1) {
      items.removeLast()
      return "hello" } }
      .wait()
      .success
    XCTAssertEqual(result, "hello")
    XCTAssertEqual(items, [])
  }

  // MARK: - try exectue times

  func testTryExecuteTimesSuccess() {
    var items = [1, 2, 3, 4, 5]
    var completions: [Fallible<String>] = [
      .failure(TestError.testCode),
      .failure(TestError.otherCode),
      .success("hello")
    ]
    func validate(completion: Fallible<String>) -> Bool { return true }

    let result = tryExecute(times: 3) { () -> String in
      items.removeLast()
      return try completions.removeFirst().liftSuccess()
      }
      .wait()
      .success
    XCTAssertEqual(result, "hello")
    XCTAssertEqual(items, [1, 2])
  }

  func testTryExecuteTimesFailure() {
    var items = [1, 2, 3, 4, 5]
    var completions: [Fallible<String>] = [
      .failure(TestError.testCode),
      .failure(TestError.otherCode),
      .failure(TestError.testCode),
      .success("hello")
    ]
    func validate(completion: Fallible<String>) -> Bool { return true }

    let result = tryExecute(times: 3) { () -> String in
      items.removeLast()
      return try completions.removeFirst().liftSuccess()
      }
      .wait()
      .failure
    XCTAssertEqual(result as? TestError, TestError.testCode)
    XCTAssertEqual(items, [1, 2])
  }

  // MARK: - try flat exectue times

  func testTryFlatExecuteTimesSuccess() {
    var items = [1, 2, 3, 4, 5]
    var completions: [Fallible<String>] = [
      .failure(TestError.testCode),
      .failure(TestError.otherCode),
      .success("hello")
    ]
    func validate(completion: Fallible<String>) -> Bool { return true }

    let result = tryFlatExecute(times: 3) { () -> Future<String> in
      items.removeLast()
      return future(after: 0.1) { try completions.removeFirst().liftSuccess() }
      }
      .wait()
      .success
    XCTAssertEqual(result, "hello")
    XCTAssertEqual(items, [1, 2])
  }

  func testTryFlatExecuteTimesFailure() {
    var items = [1, 2, 3, 4, 5]
    var completions: [Fallible<String>] = [
      .failure(TestError.testCode),
      .failure(TestError.otherCode),
      .failure(TestError.testCode),
      .success("hello")
    ]
    func validate(completion: Fallible<String>) -> Bool { return true }

    let result = tryFlatExecute(times: 3) { () -> Future<String> in
      items.removeLast()
      return future(after: 0.1) { try completions.removeFirst().liftSuccess() }
      }
      .wait()
      .failure
    XCTAssertEqual(result as? TestError, TestError.testCode)
    XCTAssertEqual(items, [1, 2])
  }

}
