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

class Future_MakersTests: XCTestCase {

  // swiftlint:disable line_length
  static let allTests = [
    ("testMakeFutureOfBlock_Success", testMakeFutureOfBlock_Success),
    ("testMakeFutureOfBlock_Failure", testMakeFutureOfBlock_Failure),
    ("testMakeFutureOfDelayedFallibleBlock_Success", testMakeFutureOfDelayedFallibleBlock_Success),
    ("testMakeFutureOfDelayedFallibleBlock_Failure", testMakeFutureOfDelayedFallibleBlock_Failure),
    ("testMakeFutureOfContextualFallibleBlock_Success_ContextAlive", testMakeFutureOfContextualFallibleBlock_Success_ContextAlive),
    ("testMakeFutureOfContextualFallibleBlock_Success_ContextDead", testMakeFutureOfContextualFallibleBlock_Success_ContextDead),
    ("testMakeFutureOfContextualFallibleBlock_Failure_ContextAlive", testMakeFutureOfContextualFallibleBlock_Failure_ContextAlive),
    ("testMakeFutureOfContextualFallibleBlock_Failure_ContextDead", testMakeFutureOfContextualFallibleBlock_Failure_ContextDead),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextAlive", testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextAlive),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextDead", testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextDead),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Success_EarlyContextDead", testMakeFutureOfDelayedContextualFallibleBlock_Success_EarlyContextDead),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextAlive", testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextAlive),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Failure_EarlyContextDead", testMakeFutureOfDelayedContextualFallibleBlock_Failure_EarlyContextDead)
    ]
  // swiftlint:enable line_length

  func testMakeFutureOfBlock_Success() {
    let qos = pickQoS()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let futureValue = future(executor: .queue(qos)) { () -> Int in
      assert(qos: qos)
      expectation.fulfill()
      return try square_success(value)
    }

    self.waitForExpectations(timeout: 0.1)
    XCTAssertEqual(futureValue.success, square(value))
  }

  func testMakeFutureOfBlock_Failure() {
    let qos = pickQoS()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let futureValue = future(executor: .queue(qos)) { () -> Int in
      assert(qos: qos)
      expectation.fulfill()
      return try square_failure(value)
    }

    self.waitForExpectations(timeout: 0.1)
    XCTAssertEqual(futureValue.failure as? TestError, TestError.testCode)
  }

  func testMakeFutureOfDelayedFallibleBlock_Success() {
    let qos = pickQoS()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")
    let startTime = DispatchTime.now()

    let futureValue = future(executor: .queue(qos), after: 0.5) { () -> Int in
      assert(qos: qos)
      let finishTime = DispatchTime.now()
      XCTAssert(startTime + 0.3 < finishTime)
      XCTAssert(startTime + 0.7 > finishTime)
      expectation.fulfill()
      return try square_success(value)
    }

    mysleep(0.25)
    XCTAssertNil(futureValue.value)

    self.waitForExpectations(timeout: 1.0)
    mysleep(0.1)
    XCTAssertEqual(futureValue.success, square(value))
  }

  func testMakeFutureOfDelayedFallibleBlock_Failure() {
    let value = pickInt()
    let expectation = self.expectation(description: "block called")
    let startTime = DispatchTime.now()

    let futureValue = future(executor: .default, after: 0.2) { () -> Int in
      assert(qos: .default)
      let finishTime = DispatchTime.now()
      XCTAssert(startTime + 0.2 < finishTime)
      XCTAssert(startTime + 0.4 > finishTime)
      expectation.fulfill()
      return try square_failure(value)
    }

    mysleep(0.1)
    XCTAssertNil(futureValue.value)

    self.waitForExpectations(timeout: 0.5)
    XCTAssertEqual(futureValue.failure as? TestError, TestError.testCode)
  }

  func testMakeFutureOfContextualFallibleBlock_Success_ContextAlive() {
    let actor = TestActor()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let futureValue = future(context: actor) { (actor) -> Int in
      assert(actor: actor)
      expectation.fulfill()
      return try square_success(value)
    }

    self.waitForExpectations(timeout: 0.1)
    XCTAssertEqual(futureValue.success, square(value))
  }

  func testMakeFutureOfContextualFallibleBlock_Success_ContextDead() {
    let value = pickInt()

    var futureValue: Future<Int>?
    let sema = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
      let actor = TestActor()
      actor.internalQueue.async {
        sleep(1)
      }
      futureValue = future(context: actor) { (actor) -> Int in
        XCTFail()
        assert(actor: actor)
        return try square_success(value)
      }
      sema.signal()
    }

    sema.wait()
    mysleep(0.1)
    XCTAssertEqual(futureValue?.wait().maybeFailure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }

  func testMakeFutureOfContextualFallibleBlock_Failure_ContextAlive() {
    let actor = TestActor()
    let value = pickInt()
    let sema = DispatchSemaphore(value: 0)

    let futureValue = future(context: actor) { (actor) -> Int in
      assert(actor: actor)
      return try square_failure(value)
    }

    futureValue.onFailure {
      XCTAssertEqual($0 as? TestError, TestError.testCode)
      sema.signal()
    }

    XCTAssertEqual(.success, sema.wait(timeout: .now() + 1.0))
    XCTAssertEqual(futureValue.failure as? TestError, TestError.testCode)
  }

  func testMakeFutureOfContextualFallibleBlock_Failure_ContextDead() {
    let value = pickInt()

    var futureValue: Future<Int>?

    let sema = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
      let actor = TestActor()
      actor.internalQueue.async {
        sleep(1)
      }
      futureValue = future(context: actor) { (actor) -> Int in
        XCTFail()
        assert(actor: actor)
        return try square_failure(value)
      }
      sema.signal()
    }

    sema.wait()
    mysleep(0.1)
    XCTAssertEqual(futureValue?.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }

  func testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextAlive() {
    let actor = TestActor()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let start = Date()
    let futureValue = future(context: actor, after: 0.2) { (actor) -> Int in
      XCTAssert((0.15...0.4).contains(-start.timeIntervalSinceNow))
      assert(actor: actor)
      expectation.fulfill()
      return try square_success(value)
    }

    waitForExpectations(timeout: 1.0)
    XCTAssertEqual(futureValue.success, square(value))
  }

  func testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextDead() {
    var actor: TestActor? = TestActor()
    let value = pickInt()

    let futureValue = future(context: actor!, after: 0.5) { (actor) -> Int in
      XCTFail()
      assert(actor: actor)
      return try square_success(value)
    }

    mysleep(0.2)
    XCTAssertNil(futureValue.value)
    actor = nil

    mysleep(1.0)
    XCTAssertEqual(futureValue.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }

  func testMakeFutureOfDelayedContextualFallibleBlock_Success_EarlyContextDead() {
    var actor: TestActor? = TestActor()
    let value = pickInt()

    let futureValue = future(context: actor!, after: 0.2) { (actor) -> Int in
      XCTFail()
      assert(actor: actor)
      return try square_success(value)
    }

    actor = nil
    mysleep(0.1)
    XCTAssertEqual(futureValue.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }

  func testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextAlive() {
    let actor = TestActor()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let start = Date()
    let futureValue = future(context: actor, after: 0.2) { (actor) -> Int in
      XCTAssert((0.15...0.4).contains(-start.timeIntervalSinceNow))
      assert(actor: actor)
      expectation.fulfill()
      return try square_failure(value)
    }

    self.waitForExpectations(timeout: 1.0)
    XCTAssertEqual(futureValue.failure as? TestError, TestError.testCode)
  }

  func testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextDead() {
    var actor: TestActor? = TestActor()
    let value = pickInt()

    let futureValue = future(context: actor!, after: 0.2) { (actor) -> Int in
      XCTFail()
      assert(actor: actor)
      return try square_success(value)
    }

    mysleep(0.15)
    XCTAssertNil(futureValue.value)
    actor = nil

    XCTAssertEqual(futureValue.wait(seconds: 0.5)?.maybeFailure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }

  func testMakeFutureOfDelayedContextualFallibleBlock_Failure_EarlyContextDead() {
    var actor: TestActor? = TestActor()
    let value = pickInt()

    let futureValue = future(context: actor!, after: 0.2) { (actor) -> Int in
      XCTFail()
      assert(actor: actor)
      return try square_success(value)
    }

    actor = nil
    mysleep(0.1)
    XCTAssertEqual(futureValue.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }
}
