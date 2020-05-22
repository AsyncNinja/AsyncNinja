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

class EventSource_ToFutureTests: XCTestCase {

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
    ("testContainsTrue", testContainsTrue),
    ("testContainsFalse", testContainsFalse),
    ("testContainsValueTrue", testContainsValueTrue),
    ("testContainsValueFalse", testContainsValueFalse)
    ]

  func testFirstSuccessIncomplete() {
    multiTest(repeating: 100) {
      let updatable = Producer<Int, Void>()
      let sema = DispatchSemaphore(value: 0)
      let qos = pickQoS()

      updatable.first(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        return 0 == $0 % 2
        }
        .onSuccess(executor: .queue(qos)) {
          assert(nonGlobalQoS: qos)
          XCTAssertEqual(8, $0)
          sema.signal()
      }

      updatable.update(1)
      updatable.update(3)
      updatable.update(5)
      updatable.update(7)
      updatable.update(8)
      updatable.update(9)
      updatable.update(10)

      sema.wait()
    }
  }

  func testFirstNotFound() {
    multiTest(repeating: 100) {
      let updatable = Producer<Int, Void>()
      let sema = DispatchSemaphore(value: 0)
      let qos = pickQoS()

      updatable.first(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        return 0 == $0 % 2
        }
        .onSuccess(executor: .queue(qos)) {
          assert(nonGlobalQoS: qos)
          XCTAssertNil($0)
          sema.signal()
      }

      updatable.update(1)
      updatable.update(3)
      updatable.update(5)
      updatable.update(7)
      updatable.update(9)
      updatable.succeed()
      sema.wait()
    }
  }

  func testFirstFailure() {
    multiTest(repeating: 100) {
      let updatable = Producer<Int, Void>()
      let sema = DispatchSemaphore(value: 0)
      let qos = pickQoS()

      updatable.first(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        return 0 == $0 % 2
        }
        .onFailure(executor: .queue(qos)) {
          assert(nonGlobalQoS: qos)
          XCTAssertEqual($0 as! TestError, TestError.testCode)
          sema.signal()
      }

      updatable.update(1)
      updatable.update(3)
      updatable.update(5)
      updatable.update(7)
      updatable.update(9)
      updatable.fail(TestError.testCode)

      sema.wait()
    }
  }

  func testFirstSuccessIncompleteContextual() {
    let actor = TestActor()
    let updatable = Producer<Int, Void>()
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
    let updatable = Producer<Int, Void>()
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
    let updatable = Producer<Int, Void>()
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
    updatable.fail(TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testFirstDeadContextual() {
    var actor: TestActor? = TestActor()
    let updatable = Producer<Int, Void>()
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
    updatable.fail(TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastSuccess() {
    multiTest(repeating: 10) {
      let updatable = Producer<Int, Void>()
      let sema = DispatchSemaphore(value: 0)
      let qos = pickQoS()

      updatable.last(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        return 0 == $0 % 2
        }
        .onSuccess(executor: .queue(qos)) {
          assert(nonGlobalQoS: qos)
          XCTAssertEqual(10, $0)
          sema.signal()
      }

      updatable.update(1)
      updatable.update(3)
      updatable.update(5)
      updatable.update(7)
      updatable.update(8)
      updatable.update(9)
      updatable.update(10)
      updatable.succeed()

      sema.wait()
    }
  }

  func testLastNotFound() {
    let updatable = Producer<Int, Void>()
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
    let updatable = Producer<Int, Void>()
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
    updatable.fail(TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastSuccessContextual() {
    let actor = TestActor()
    let updatable = Producer<Int, Void>()
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
    let updatable = Producer<Int, Void>()
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
    let updatable = Producer<Int, Void>()
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
    updatable.fail(TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastDeadContextual() {
    var actor: TestActor? = TestActor()
    let updatable = Producer<Int, Void>()
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
    updatable.fail(TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testContainsTrue() {
    let source = Producer<Int, String>()
    let sema = DispatchSemaphore(value: 0)
    source.contains { $0 >= 10 }
      .onSuccess {
        XCTAssert($0)
        sema.signal()
    }
    source.update(0..<11)
    sema.wait()
    source.update(0..<20)
    source.succeed("Done")
  }

  func testContainsFalse() {
    let source = Producer<Int, String>()
    let sema = DispatchSemaphore(value: 0)
    source.contains { $0 >= 10 }
      .onSuccess {
        XCTAssertFalse($0)
        sema.signal()
    }
    source.update(0..<10)
    source.succeed("Done")
    sema.wait()
  }

  func testContainsValueTrue() {
    let source = Producer<Int, String>()
    let sema = DispatchSemaphore(value: 0)
    source.contains(10)
      .onSuccess {
        XCTAssert($0)
        sema.signal()
    }
    source.update(0..<11)
    sema.wait()
    source.update(0..<20)
    source.succeed("Done")
  }

  func testContainsValueFalse() {
    let source = Producer<Int, String>()
    let sema = DispatchSemaphore(value: 0)
    source.contains(10)
      .onSuccess {
        XCTAssertFalse($0)
        sema.signal()
    }
    source.update(0..<10)
    source.succeed("Done")
    sema.wait()
  }
}
