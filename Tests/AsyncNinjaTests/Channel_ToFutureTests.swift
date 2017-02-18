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

class Channel_ToFutureTests: XCTestCase {

  static let allTests = [
    ("testFirstSuccessIncomplete", testFirstSuccessIncomplete),
    ("testFirstNotFound", testFirstNotFound),
    ("testFirstFailure", testFirstFailure),
    ("testFirstSuccessIncompleteContextual", testFirstSuccessIncompleteContextual),
    ("testFirstNotFoundContextual", testFirstNotFoundContextual),
    ("testFirstFailureContextual", testFirstFailureContextual),
    ("testFirstDeadContextual", testFirstDeadContextual),
    ("testLastSuccess", testLastSuccess),
    ("testLastNotFound", testLastNotFound),
    ("testLastFailure", testLastFailure),
    ("testLastSuccessContextual", testLastSuccessContextual),
    ("testLastNotFoundContextual", testLastNotFoundContextual),
    ("testLastFailureContextual", testLastFailureContextual),
    ("testLastDeadContextual", testLastDeadContextual),
    ("testReduce", testReduce),
    ("testReduceContextual", testReduceContextual),
    ]

  func testFirstSuccessIncomplete() {
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")
    let qos = pickQoS()

    updatable.first(executor: .queue(qos)) {
      assert(nonGlobalQoS: qos)
      return 0 == $0 % 2
      }
      .onSuccess(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        XCTAssertEqual(8, $0)
        expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    updatable.update(5)
    updatable.update(7)
    updatable.update(8)
    updatable.update(9)
    updatable.update(10)

    self.waitForExpectations(timeout: 1.0)
  }

  func testFirstNotFound() {
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")
    let qos = pickQoS()

    updatable.first(executor: .queue(qos)) {
      assert(nonGlobalQoS: qos)
      return 0 == $0 % 2
      }
      .onSuccess(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        XCTAssertNil($0)
        expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    updatable.update(5)
    updatable.update(7)
    updatable.update(9)
    updatable.succeed()

    self.waitForExpectations(timeout: 1.0)
  }

  func testFirstFailure() {
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")
    let qos = pickQoS()

    updatable.first(executor: .queue(qos)) {
      assert(nonGlobalQoS: qos)
      return 0 == $0 % 2
      }
      .onFailure(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        XCTAssertEqual($0 as! TestError, TestError.testCode)
        expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    updatable.update(5)
    updatable.update(7)
    updatable.update(9)
    updatable.fail(with: TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testFirstSuccessIncompleteContextual() {
    let actor = TestActor()
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")

    updatable.first(context: actor) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
      }
      .onSuccess(context: actor) { (actor, value) in
        assert(actor: actor)
        XCTAssertEqual(8, value)
        expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    updatable.update(5)
    updatable.update(7)
    updatable.update(8)
    updatable.update(9)
    updatable.update(10)

    self.waitForExpectations(timeout: 1.0)
  }

  func testFirstNotFoundContextual() {
    let actor = TestActor()
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")

    updatable.first(context: actor) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
      }
      .onSuccess(context: actor) { (actor, value) in
        assert(actor: actor)
        XCTAssertNil(value)
        expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    updatable.update(5)
    updatable.update(7)
    updatable.update(9)
    updatable.succeed()

    self.waitForExpectations(timeout: 1.0)
  }

  func testFirstFailureContextual() {
    let actor = TestActor()
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")

    updatable.first(context: actor) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
      }
      .onFailure(context: actor) { (actor, failure) in
        assert(actor: actor)
        XCTAssertEqual(failure as! TestError, TestError.testCode)
        expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    updatable.update(5)
    updatable.update(7)
    updatable.update(9)
    updatable.fail(with: TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testFirstDeadContextual() {
    var actor: TestActor? = TestActor()
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")

    let future = updatable.first(context: actor!) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
    }
    future.onFailure { (failure) in
      XCTAssertEqual(failure as! AsyncNinjaError, AsyncNinjaError.contextDeallocated)
      expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    actor = nil
    updatable.update(5)
    updatable.update(8)
    updatable.update(7)
    updatable.update(9)
    updatable.fail(with: TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastSuccess() {
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")
    let qos = pickQoS()

    updatable.last(executor: .queue(qos)) {
      assert(nonGlobalQoS: qos)
      return 0 == $0 % 2
      }
      .onSuccess(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        XCTAssertEqual(10, $0)
        expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    updatable.update(5)
    updatable.update(7)
    updatable.update(8)
    updatable.update(9)
    updatable.update(10)
    updatable.succeed()

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastNotFound() {
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")
    let qos = pickQoS()

    updatable.last(executor: .queue(qos)) {
      assert(nonGlobalQoS: qos)
      return 0 == $0 % 2
      }
      .onSuccess(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        XCTAssertNil($0)
        expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    updatable.update(5)
    updatable.update(7)
    updatable.update(9)
    updatable.succeed()

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastFailure() {
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")
    let qos = pickQoS()

    updatable.last(executor: .queue(qos)) {
      assert(nonGlobalQoS: qos)
      return 0 == $0 % 2
      }
      .onFailure(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        XCTAssertEqual($0 as! TestError, TestError.testCode)
        expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    updatable.update(5)
    updatable.update(7)
    updatable.update(9)
    updatable.fail(with: TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastSuccessContextual() {
    let actor = TestActor()
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")

    updatable.last(context: actor) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
      }
      .onSuccess(context: actor) { (actor, value) in
        assert(actor: actor)
        XCTAssertEqual(10, value)
        expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    updatable.update(5)
    updatable.update(7)
    updatable.update(8)
    updatable.update(9)
    updatable.update(10)
    updatable.succeed()

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastNotFoundContextual() {
    let actor = TestActor()
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")

    updatable.last(context: actor) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
      }
      .onSuccess(context: actor) { (actor, value) in
        assert(actor: actor)
        XCTAssertNil(value)
        expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    updatable.update(5)
    updatable.update(7)
    updatable.update(9)
    updatable.succeed()

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastFailureContextual() {
    let actor = TestActor()
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")

    updatable.last(context: actor) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
      }
      .onFailure(context: actor) { (actor, failure) in
        assert(actor: actor)
        XCTAssertEqual(failure as! TestError, TestError.testCode)
        expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    updatable.update(5)
    updatable.update(7)
    updatable.update(9)
    updatable.fail(with: TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastDeadContextual() {
    var actor: TestActor? = TestActor()
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "future to finish")

    let future = updatable.last(context: actor!) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
    }
    future.onFailure { (failure) in
      XCTAssertEqual(failure as! AsyncNinjaError, AsyncNinjaError.contextDeallocated)
      expectation.fulfill()
    }

    updatable.update(1)
    updatable.update(3)
    actor = nil
    updatable.update(5)
    updatable.update(8)
    updatable.update(7)
    updatable.update(9)
    updatable.fail(with: TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testReduceContextual() {
    let actor = TestActor()
    let producer = Producer<String, Int>()
    let expectation = self.expectation(description: "future to complete")

    let future = producer.reduce("A", context: actor) { (actor, accumulator, value) -> String in
      assert(actor: actor)
      return accumulator + value
    }

    future.onSuccess { (concatString, successValue) in
      XCTAssertEqual(concatString, "ABCDEF")
      XCTAssertEqual(successValue, 7)
      expectation.fulfill()
    }

    producer.update("B")
    producer.update("C")
    producer.update("D")
    producer.update("E")
    producer.update("F")
    producer.succeed(with: 7)
    self.waitForExpectations(timeout: 1.0)
  }

  func testReduce() {
    multiTest {
      let producer = Producer<String, Int>()
      let sema = DispatchSemaphore(value: 0)

      let future = producer.reduce("A") { (accumulator, value) -> String in
        return accumulator + value
      }
      
      future.onSuccess { (concatString, successValue) in
        XCTAssertEqual(concatString, "ABCDEF")
        XCTAssertEqual(successValue, 7)
        sema.signal()
      }
      
      producer.update("B")
      producer.update("C")
      producer.update("D")
      producer.update("E")
      producer.update("F")
      producer.succeed(with: 7)
      sema.wait()
    }
  }
}