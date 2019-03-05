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

class FutureTests: XCTestCase {

  static let allTests = [
    ("testLifetime", testLifetime),
    ("testMapLifetime", testMapLifetime),
    ("testPureMapLifetime", testPureMapLifetime),
    ("testImpureMapLifetime", testImpureMapLifetime),
    ("testMap_Success", testMap_Success),
    ("testMap_Failure", testMap_Failure),
    ("testMapContextual_Success_ContextAlive", testMapContextual_Success_ContextAlive),
    ("testMapContextual_Success_ContextDead", testMapContextual_Success_ContextDead),
    ("testMapContextual_Failure_ContextAlive", testMapContextual_Failure_ContextAlive),
    ("testMapContextual_Failure_ContextDead", testMapContextual_Failure_ContextDead),
    ("testOnCompleteContextual_ContextAlive_RegularActor", testOnCompleteContextual_ContextAlive_RegularActor),
    ("testOnCompleteContextual_ContextAlive_ObjcActor", testOnCompleteContextual_ContextAlive_ObjcActor),
    ("testOnCompleteContextual_ContextDead", testOnCompleteContextual_ContextDead),
    ("testFlatten", testFlatten),
    ("testFlatten_OuterFailure", testFlatten_OuterFailure),
    ("testFlatten_InnerFailure", testFlatten_InnerFailure),
    ("testChannelFlatten", testChannelFlatten),
    ("testGroupCompletionFuture", testGroupCompletionFuture),
    ("testOnCompleteOnMultipleExecutors", testOnCompleteOnMultipleExecutors),
    ("testDescription", testDescription)
    ]

  func testLifetime() {
    let queue = DispatchQueue(label: "testing queue", qos: DispatchQoS(qosClass: .default, relativePriority: 0))
    multiTest(repeating: 100) {
      weak var weakFuture: Future<Int>?
      weak var weakMappedFuture: Future<Int>?

      let fixtureResult = pickInt()
      var result: Int?

      queue.sync {
        var futureValue: Future<Int>? = .succeeded(fixtureResult)
        let qos = pickQoS()
        var mappedFutureValue: Future<Int>? = futureValue!
          .map(executor: .queue(qos)) { (value) -> Int in
            assert(qos: qos)
            return value * 3
        }
        weakFuture = futureValue
        weakMappedFuture = mappedFutureValue
        result = mappedFutureValue!.wait().maybeSuccess
        futureValue = nil
        mappedFutureValue = nil
      }

      queue.sync {
        // wainting for previus sync to cleanup
        mysleep(0.0001)
      }

      XCTAssertEqual(result, fixtureResult * 3)
      XCTAssertNil(weakFuture)
      XCTAssertNil(weakMappedFuture)
    }
  }

  func testMapLifetime() {
    let qos = pickQoS()

    weak var weakFutureValue: Future<Int>?
    weak var weakMappedFuture: Future<String>?
    eval { () -> Void in
      var futureValue: Future<Int>? = future(executor: .queue(qos), after: 1.0) { 1 }
      weakFutureValue = futureValue

      var mappedFuture: Future<String>? = futureValue!.map { _ in
        XCTFail()
        return "hello"
      }
      weakMappedFuture = mappedFuture

      mappedFuture = nil
      futureValue = nil
    }

    XCTAssertNil(weakFutureValue)
    XCTAssertNil(weakMappedFuture)
  }

  func testPureMapLifetime() {
    let qos = pickQoS()
    var futureValue: Future<Int>?
    weak var weakMappedFuture: Future<String>?
    eval { () -> Void in
      futureValue = future(executor: .queue(qos), after: 0.1) { 1 }

      var mappedFuture: Future<String>? = futureValue!.map(pure: true) { _ in
        XCTFail()
        return "hello"
      }
      weakMappedFuture = mappedFuture

      mappedFuture = nil
      futureValue = nil
    }

    XCTAssertNil(weakMappedFuture)
    sleep(1)
  }

  func testImpureMapLifetime() {
    let qos = pickQoS()
    var futureValue: Future<Int>?
    weak var weakMappedFuture: Future<String>?
    let sema = DispatchSemaphore(value: 0)

    eval { () -> Void in
      futureValue = future(executor: .queue(qos), after: 0.1) { 1 }

      var mappedFuture: Future<String>? = futureValue!.map(pure: false) { _ in
        sema.signal()
        return "hello"
      }
      weakMappedFuture = mappedFuture

      mappedFuture = nil
      futureValue = nil
    }

    XCTAssertNil(weakMappedFuture)
    sema.wait()
  }

  func testMap_Success() {
    let queue = DispatchQueue(label: "aaa")
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
    let valueSquared = square(value)

    let mappedFuture: Future<Int> = eval {
      let initialFuture = future(success: value)
      weakInitialFuture = initialFuture
      return initialFuture
        .map(executor: .queue(queue)) {
          assert(on: queue)
          return try square_success($0)
      }
    }

    let result = mappedFuture.wait()
    queue.sync { nop() }
    XCTAssertNil(weakInitialFuture)
    XCTAssertEqual(result.maybeSuccess!, valueSquared)
  }

  func testMap_Failure() {
    let queue = DispatchQueue(label: "aaa")
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
    let result: Fallible<Int> = eval {
      let initialFuture = future(success: value)
      weakInitialFuture = initialFuture
      return initialFuture
        .map(executor: .queue(queue)) {
          assert(on: queue)
          return try square_failure($0)
        }
        .wait()
    }

    queue.sync { nop() }
    XCTAssertNil(weakInitialFuture)
    XCTAssertEqual(result.maybeFailure as? TestError, .testCode)
  }

  func testMapContextual_Success_ContextAlive() {
    let actor = TestActor()
    let transformExpectation = self.expectation(description: "transform called")
    weak var weakInitialFuture: Future<Int>?
    weak var weakMappedFuture: Future<Int>?
    let value = pickInt()
    let valueSquared = square(value)

    var mappedFuture: Future<Int>? = eval {
      let initialFuture = future(success: value)
      weakInitialFuture = initialFuture
      let mappedFuture = initialFuture
        .map(context: actor) { (actor, value) -> Int in
          assert(actor: actor)
          transformExpectation.fulfill()
          return try square_success(value)
      }
      weakMappedFuture = mappedFuture
      return mappedFuture
    }

    self.waitForExpectations(timeout: 0.1)
    let result = mappedFuture!.wait()
    mappedFuture = nil
    actor.internalQueue.sync { nop() }
    XCTAssertNil(weakInitialFuture)
    XCTAssertNil(weakMappedFuture)
    XCTAssertEqual(result.maybeSuccess!, valueSquared)
  }

  func testMapContextual_Success_ContextDead() {
//    let transformExpectation = self.expectation(description: "transform called")
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
//    let valueSquared = square(value)

    let mappedFuture: Future<Int> = eval {
      let initialFuture = future(success: value)
      weakInitialFuture = initialFuture
      let actor = TestActor()
      let result: Future<Int> = initialFuture
        .delayed(timeout: 0.1)
        .map(context: actor) { (actor, value) in
          assert(actor: actor)
          XCTFail()
//          transformExpectation.fulfill()
          return try square_success(value)
      }
      actor.internalQueue.sync { nop() }
      return result
    }

    // self.waitForExpectations(timeout: 1.0)
    let result = mappedFuture.wait()
    XCTAssertNil(weakInitialFuture)
    XCTAssertEqual(result.maybeFailure as? AsyncNinjaError, .contextDeallocated)
  }

  func testMapContextual_Failure_ContextAlive() {
    multiTest(repeating: 1000) {
      let actor = TestActor()
      let sema = DispatchSemaphore(value: 0)
      weak var weakInitialFuture: Future<Int>?
      let value = pickInt()

      let result: Fallible<Int> = eval {
        let initialFuture: Future<Int> = future(success: value)
        weakInitialFuture = initialFuture
        let mappedFuture: Future<Int> = initialFuture
          .map(context: actor) { (actor, value) in
            assert(actor: actor)
            sema.signal()
            return try square_failure(value)
        }

        sema.wait()
        let result = mappedFuture.wait()
        actor.internalQueue.sync { nop() }
        return result
      }

      actor.internalQueue.sync { nop() }
      XCTAssertNil(weakInitialFuture)
      XCTAssertEqual(result.maybeFailure as? TestError, .testCode)
    }
  }

  func testMapContextual_Failure_ContextDead() {
    //let transformExpectation = self.expectation(description: "transform called")
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
    //let valueSquared = square(value)

    let mappedFuture: Future<Int> = eval {
      let initialFuture = future(success: value)
      weakInitialFuture = initialFuture
      let actor = TestActor()
      let result: Future<Int> = initialFuture
        .delayed(timeout: 0.1)
        .map(context: actor) { (actor, value) in
          XCTFail()
          assert(actor: actor)
          //transformExpectation.fulfill()
          return try square_failure(value)
      }

      actor.internalQueue.sync { nop() }
      return result
    }

    //self.waitForExpectations(timeout: 0.1)
    let result = mappedFuture.wait()
    XCTAssertNil(weakInitialFuture)
    XCTAssertEqual(result.maybeFailure as? AsyncNinjaError, .contextDeallocated)
  }

  func testOnCompleteContextual_ContextAlive_RegularActor() {
    _testOnCompleteContextual_ContextAlive(makeActor: TestActor.init)
  }

  func testOnCompleteContextual_ContextAlive_ObjcActor() {
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    _testOnCompleteContextual_ContextAlive(makeActor: TestObjCActor.init)
    #endif
  }

  func _testOnCompleteContextual_ContextAlive<T: Actor>(makeActor: @escaping () -> T) {
    multiTest {
      let actor = makeActor()
      weak var weakInitialFuture: Future<Int>?
      let value = pickInt()

      let group = DispatchGroup()
      group.enter()
      DispatchQueue.global().async {
        let initialFuture = future(success: value)
        weakInitialFuture = initialFuture
        initialFuture
          .flatMap { value in future(after: 0.1) { value } }
          .onSuccess(context: actor) { (actor, value_) in
            assert(actor: actor)
            XCTAssertEqual(value, value_)
            group.leave()
          }
          .onFailure { _ in XCTFail() }
      }

      group.wait()
      XCTAssertNil(weakInitialFuture)
    }
  }

  func testOnCompleteContextual_ContextDead() {
    multiTest(repeating: 100) {
      weak var weakInitialFuture: Future<Int>?
      weak var weakDelayedFuture: Future<Int>?
      let sema = DispatchSemaphore(value: 0)

      DispatchQueue.global().async {
        let value = pickInt()
        var actor: TestActor? = TestActor()

        var initialFuture: Future<Int>? = future(success: value)
        weakInitialFuture = initialFuture

        var delayedFuture: Future<Int>? = initialFuture!.delayed(timeout: 0.1)
        weakDelayedFuture = delayedFuture

        delayedFuture!.onComplete(context: actor!) { (actor, _) in
          XCTFail()
          assert(actor: actor)
        }

        initialFuture = nil
        delayedFuture = nil
        actor = nil
        sema.signal()
      }

      sema.wait()
      XCTAssertNil(weakInitialFuture)
      XCTAssertNil(weakDelayedFuture)
    }
  }

  func testFlatten() {
    let value = pickInt()
    let future3D = future(executor: .queue(pickQoS())) {
      return future(executor: .queue(pickQoS())) { value }
    }
    let future2D = future3D.flatten()
    let failable = future2D.wait()
    XCTAssertEqual(failable.maybeSuccess, value)
  }

  func testFlatten_OuterFailure() {
    func fail() throws -> Future<Int> { throw AsyncNinjaError.cancelled }
    let future3D = future(executor: .default) { try fail() }
    let future2D = future3D.flatten()
    let failable = future2D.wait()
    XCTAssertEqual(failable.maybeFailure! as? AsyncNinjaError, AsyncNinjaError.cancelled)
  }

  func testFlatten_InnerFailure() {
    func fail() throws -> Future<Int> { throw AsyncNinjaError.cancelled }
    let startTime = DispatchTime.now()
    let timeout = startTime + 0.7
    let future3D = future(after: 0.2) { return future(after: 0.3) { try fail() } }
    let future2D = future3D.flatten()
    if let failable = future2D.wait(timeout: timeout) {
      XCTAssertEqual(failable.maybeFailure! as? AsyncNinjaError, AsyncNinjaError.cancelled)
      let finishTime = DispatchTime.now()
      XCTAssert(startTime + 0.3 < finishTime)
      XCTAssert(startTime + 0.7 > finishTime)
    } else {
      XCTFail("timeout")
    }
  }

  func testChannelFlatten() {
    let startTime = DispatchTime.now()
    let value = pickInt()
    let futureOfChannel = future(after: 0.2) { () -> Channel<String, Int> in
      return channel { (update) -> Int in
        mysleep(0.05)
        update("a")
        mysleep(0.05)
        update("b")
        mysleep(0.05)
        update("c")
        mysleep(0.05)
        update("d")
        mysleep(0.05)
        update("e")
        mysleep(0.05)
        return value
      }
    }
    let flattenedChannel = futureOfChannel.flatten()
    let (updates, failable) = flattenedChannel.waitForAll()
    let finishTime = DispatchTime.now()
    XCTAssertEqual(updates, ["a", "b", "c", "d", "e"])
    XCTAssertEqual(failable.maybeSuccess, value)
    XCTAssert(startTime + 0.3 < finishTime)
    XCTAssert(startTime + 1.2 > finishTime)
  }

  func testGroupCompletionFuture() {
    let group = DispatchGroup()
    group.enter()
    let completionFuture = group.completionFuture

    XCTAssertNil(completionFuture.value)
    group.leave()

    let expectation = self.expectation(description: "completion of future")
    completionFuture
      .onSuccess { _ in expectation.fulfill() }
      .onFailure { _ in XCTFail() }

    self.waitForExpectations(timeout: 0.2)
  }

  func testOnCompleteOnMultipleExecutors() {
    let executors: [Executor] = [
      .primary,
      .immediate,
      .userInteractive,
      .userInitiated,
      .default,
      .utility,
      .background
    ]
    multiTest {
      let expectedValue = pickInt()
      let futureValue = future(after: 0.1) { return expectedValue }
      let group = DispatchGroup()
      for executor in executors {
        group.enter()
        futureValue.onSuccess(executor: executor) { (actualValue) in
          XCTAssertEqual(expectedValue, actualValue)
          group.leave()
        }
      }

      group.wait()
    }
  }

  func testDescription() {
    let futureA = future(success: 1)
    XCTAssertEqual("Succeded(1) Future", futureA.description)
    XCTAssertEqual("Succeded(1) Future<Int>", futureA.debugDescription)

    let futureB: Future<Int> = .failed(TestError.testCode)
    #if swift(>=5.0)
    XCTAssertEqual("Failed(TestError) Future", futureB.description)
    XCTAssertEqual("Failed(TestError) Future<Int>", futureB.debugDescription)
    #else
    XCTAssertEqual("Failed(testCode) Future", futureB.description)
    XCTAssertEqual("Failed(testCode) Future<Int>", futureB.debugDescription)
    #endif

    let futureC = Promise<Int>()
    XCTAssertEqual("Incomplete Future", futureC.description)
    XCTAssertEqual("Incomplete Future<Int>", futureC.debugDescription)
  }
}
