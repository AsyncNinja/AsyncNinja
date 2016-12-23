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

class FutureTests : XCTestCase {

  static let allTests = [
    ("testLifetime", testLifetime),
    ("testPerformanceFuture", testPerformanceFuture),
    ("testMapLifetime", testMapLifetime),
    ("testMap_Success", testMap_Success),
    ("testMap_Failure", testMap_Failure),
    ("testMapContextual_Success_ContextAlive", testMapContextual_Success_ContextAlive),
    ("testMapContextual_Success_ContextDead", testMapContextual_Success_ContextDead),
    ("testMapContextual_Failure_ContextAlive", testMapContextual_Failure_ContextAlive),
    ("testMapContextual_Failure_ContextDead", testMapContextual_Failure_ContextDead),
    ("testOnCompleteContextual_ContextAlive", testOnCompleteContextual_ContextAlive),
    ("testOnCompleteContextual_ContextDead", testOnCompleteContextual_ContextDead),
    ("testMakeFutureOfBlock_Success", testMakeFutureOfBlock_Success),
    ("testMakeFutureOfBlock_Failure", testMakeFutureOfBlock_Failure),
    ("testMakeFutureOfDelayedFallibleBlock_Success", testMakeFutureOfDelayedFallibleBlock_Success),
    ("testMakeFutureOfDelayedFallibleBlock_Failure", testMakeFutureOfDelayedFallibleBlock_Failure),
    ("testMakeFutureOfContextualFallibleBlock_Success_ContextAlive", testMakeFutureOfContextualFallibleBlock_Success_ContextAlive),
    ("testMakeFutureOfContextualFallibleBlock_Success_ContextDead", testMakeFutureOfContextualFallibleBlock_Success_ContextDead),
    ("testMakeFutureOfContextualFallibleBlock_Failure_ContextAlive", testMakeFutureOfContextualFallibleBlock_Failure_ContextAlive),
    ("testMakeFutureOfContextualFallibleBlock_Failure_ContextDead", testMakeFutureOfContextualFallibleBlock_Failure_ContextDead),
    ("testFlatten", testFlatten),
    ("testFlatten_OuterFailure", testFlatten_OuterFailure),
    ("testFlatten_InnerFailure", testFlatten_InnerFailure),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextAlive", testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextAlive),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextDead", testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextDead),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Success_EarlyContextDead", testMakeFutureOfDelayedContextualFallibleBlock_Success_EarlyContextDead),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextAlive", testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextAlive),
    ("testMakeFutureOfDelayedContextualFallibleBlock_Failure_EarlyContextDead", testMakeFutureOfDelayedContextualFallibleBlock_Failure_EarlyContextDead),
    ("testGroupCompletionFuture", testGroupCompletionFuture),
    ]

  func testLifetime() {

    weak var weakFuture: Future<Int>?
    weak var weakMappedFuture: Future<Int>?

    let result: Int = eval {
      let futureValue = future(success: 1)
      let mappedFutureValue = futureValue.map(executor: .utility) { (value) -> Int in
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
          assert(qos: .utility)
        }
        return value * 3
      }
      weakFuture = futureValue
      weakMappedFuture = mappedFutureValue
      return mappedFutureValue.wait().success!
    }

    sleep(1) // this test succeeds when utility queue has time to release futures

    XCTAssertEqual(result, 3)
    XCTAssertNil(weakFuture)
    XCTAssertNil(weakMappedFuture)
  }

  func testPerformanceFuture() {
    self.measure {
      
      func makePerformer(globalQOS: DispatchQoS.QoSClass, multiplier: Int) -> (Int) -> Int {
        return {
          assert(qos: globalQOS)
          return $0 * multiplier
        }
      }
      
      let result1 = future(success: 1)
        .map(executor: .userInteractive, transform: makePerformer(globalQOS: .userInteractive, multiplier: 2))
        .map(executor: .default, transform: makePerformer(globalQOS: .default, multiplier: 3))
        .map(executor: .utility, transform: makePerformer(globalQOS: .utility, multiplier: 4))
        .map(executor: .background, transform: makePerformer(globalQOS: .background, multiplier: 5))

      let result2 = future(success: 2)
        .map(executor: .background, transform: makePerformer(globalQOS: .background, multiplier: 5))
        .map(executor: .utility, transform: makePerformer(globalQOS: .utility, multiplier: 4))
        .map(executor: .default, transform: makePerformer(globalQOS: .default, multiplier: 3))
        .map(executor: .userInteractive, transform: makePerformer(globalQOS: .userInteractive, multiplier: 2))
      
      let result = zip(result1, result2).map { $0 + $1 }.wait().success!

      XCTAssertEqual(result, 360)
    }
  }

  func testMapLifetime() {
    let qos = pickQoS()
    
    weak var weakFutureValue: Future<Int>?
    weak var weakMappedFuture: Future<String>?
    eval { () -> Void in
        var futureValue: Future<Int>? = future(executor: .queue(qos), after: 1.0) { 1 }
        weakFutureValue = futureValue
        
        var mappedFuture: Future<String>? = futureValue!.map { _ in "hello" }
        weakMappedFuture = mappedFuture
        
        mappedFuture = nil
        futureValue = nil
    }
    
    XCTAssertNil(weakFutureValue)
    XCTAssertNil(weakMappedFuture)
  }

  func testMap_Success() {
    let transformExpectation = self.expectation(description: "transform called")
    let qos = pickQoS()
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
    let valueSquared = square(value)

    let mappedFuture: Future<Int> = eval {
      let initialFuture = future(success: value)
      weakInitialFuture = initialFuture
      return initialFuture
        .map(executor: .queue(qos)) {
          assert(qos: qos)
          transformExpectation.fulfill()
          return try square_success($0)
      }
    }

    self.waitForExpectations(timeout: 0.1)
    let result = mappedFuture.wait()
    XCTAssertNil(weakInitialFuture)
    XCTAssertEqual(result.success, valueSquared)
  }

  func testMap_Failure() {
    let transformExpectation = self.expectation(description: "transform called")
    let qos = pickQoS()
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
//    let valueSquared = square(value)

    let mappedFuture: Future<Int> = eval {
      let initialFuture = future(success: value)
      weakInitialFuture = initialFuture
      return initialFuture
        .map(executor: .queue(qos)) {
          assert(qos: qos)
          transformExpectation.fulfill()
          return try square_failure($0)
      }
    }

    self.waitForExpectations(timeout: 0.1)
    let result = mappedFuture.wait()
    XCTAssertNil(weakInitialFuture)
    XCTAssertEqual(result.failure as? TestError, .testCode)
  }

  func testMapContextual_Success_ContextAlive() {
    let actor = TestActor()
    let transformExpectation = self.expectation(description: "transform called")
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
    let valueSquared = square(value)

    let mappedFuture: Future<Int> = eval {
      let initialFuture = future(success: value)
      weakInitialFuture = initialFuture
      return initialFuture
        .map(context: actor) { (actor, value) in
          assert(actor: actor)
          transformExpectation.fulfill()
          return try square_success(value)
      }
    }

    self.waitForExpectations(timeout: 0.1)
    let result = mappedFuture.wait()
    XCTAssertNil(weakInitialFuture)
    XCTAssertEqual(result.success, valueSquared)
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
      return initialFuture
        .delayed(timeout: 0.1)
        .map(context: actor) { (actor, value) in
          assert(actor: actor)
          XCTFail()
//          transformExpectation.fulfill()
          return try square_success(value)
      }
    }

    // self.waitForExpectations(timeout: 1.0)
    let result = mappedFuture.wait()
    XCTAssertNil(weakInitialFuture)
    XCTAssertEqual(result.failure as? AsyncNinjaError, .contextDeallocated)
  }

  func testMapContextual_Failure_ContextAlive() {
    let actor = TestActor()
    let transformExpectation = self.expectation(description: "transform called")
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
    //let valueSquared = square(value)

    let mappedFuture: Future<Int> = eval {
      let initialFuture = future(success: value)
      weakInitialFuture = initialFuture
      return initialFuture
        .map(context: actor) { (actor, value) in
          assert(actor: actor)
          transformExpectation.fulfill()
          return try square_failure(value)
      }
    }

    self.waitForExpectations(timeout: 0.1)
    let result = mappedFuture.wait()
    XCTAssertNil(weakInitialFuture)
    XCTAssertEqual(result.failure as? TestError, .testCode)
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
      return initialFuture
        .delayed(timeout: 0.1)
        .map(context: actor) { (actor, value) in
          XCTFail()
          assert(actor: actor)
          //transformExpectation.fulfill()
          return try square_failure(value)
      }
    }

    //self.waitForExpectations(timeout: 0.1)
    let result = mappedFuture.wait()
    XCTAssertNil(weakInitialFuture)
    XCTAssertEqual(result.failure as? AsyncNinjaError, .contextDeallocated)
  }

  func testOnCompleteContextual_ContextAlive() {
    let actor = TestActor()
    let transformExpectation = self.expectation(description: "transform called")
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()

    eval {
      let initialFuture = future(success: value)
      weakInitialFuture = initialFuture
      initialFuture.onSuccess(context: actor) { (actor, value_) in
        assert(actor: actor)
        XCTAssertEqual(value, value_)
        transformExpectation.fulfill()
      }
    }

    self.waitForExpectations(timeout: 0.2)
    XCTAssertNil(weakInitialFuture)
  }

  func testOnCompleteContextual_ContextDead() {
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()

    eval {
      let actor = TestActor()
      let initialFuture = future(success: value)
      weakInitialFuture = initialFuture
      initialFuture
        .delayed(timeout: 0.1)
        .onComplete(context: actor) { (actor, value_) in
          XCTFail()
          assert(actor: actor)
      }
    }

    sleep(1)
    XCTAssertNil(weakInitialFuture)
  }

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
    
    let futureValue = future(executor: .queue(qos), after: 0.2) { () -> Int in
      assert(qos: qos)
      let finishTime = DispatchTime.now()
      XCTAssert(startTime + 0.2 < finishTime)
      XCTAssert(startTime + 0.4 > finishTime)
      expectation.fulfill()
      return try square_success(value)
    }

    usleep(150_000)
    XCTAssertNil(futureValue.value)

    self.waitForExpectations(timeout: 0.5)
    XCTAssertEqual(futureValue.success, square(value))
  }

  func testMakeFutureOfDelayedFallibleBlock_Failure() {
    let qos = pickQoS()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")
    let startTime = DispatchTime.now()

    let futureValue = future(executor: .queue(qos), after: 0.2) { () -> Int in
      assert(qos: qos)
      let finishTime = DispatchTime.now()
      XCTAssert(startTime + 0.2 < finishTime)
      XCTAssert(startTime + 0.4 > finishTime)
      expectation.fulfill()
      return try square_failure(value)
    }

    usleep(150_000)
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

    let futureValue: Future<Int> = eval {
      let actor = TestActor()
      return future(context: actor) { (actor) -> Int in
        XCTFail()
        assert(actor: actor)
        return try square_success(value)
      }
    }

    usleep(100_000)
    XCTAssertEqual(futureValue.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }

  func testMakeFutureOfContextualFallibleBlock_Failure_ContextAlive() {
    let actor = TestActor()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let futureValue = future(context: actor) { (actor) -> Int in
      assert(actor: actor)
      expectation.fulfill()
      return try square_failure(value)
    }

    self.waitForExpectations(timeout: 0.1)
    XCTAssertEqual(futureValue.failure as? TestError, TestError.testCode)
  }
  
  func testMakeFutureOfContextualFallibleBlock_Failure_ContextDead() {
    let value = pickInt()

    let futureValue: Future<Int> = eval {
      let actor = TestActor()
      return future(context: actor) { (actor) -> Int in
        XCTFail()
        assert(actor: actor)
        return try square_failure(value)
      }
    }

    usleep(100_000)
    XCTAssertEqual(futureValue.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }
  
  func testFlatten() {
    let startTime = DispatchTime.now()
    let timeout = startTime + 0.7
    let value = pickInt()
    let future3D = future(after: 0.2) { return future(after: 0.3) { value } }
    let future2D = future3D.flatten()
    if let failable = future2D.wait(timeout: timeout) {
      XCTAssertEqual(failable.success!, value)
      let finishTime = DispatchTime.now()
      XCTAssert(startTime + 0.3 < finishTime)
      XCTAssert(startTime + 0.7 > finishTime)
    } else {
      XCTFail("timeout")
    }
  }
  
  func testFlatten_OuterFailure() {
    func fail() throws -> Future<Int> { throw AsyncNinjaError.cancelled }
    let startTime = DispatchTime.now()
    let timeout = startTime + 0.4
    let future3D = future(after: 0.2) { try fail() }
    let future2D = future3D.flatten()
    if let failable = future2D.wait(timeout: timeout) {
      XCTAssertEqual(failable.failure! as? AsyncNinjaError, AsyncNinjaError.cancelled)
      let finishTime = DispatchTime.now()
      XCTAssert(startTime + 0.1 < finishTime)
      XCTAssert(startTime + 0.3 > finishTime)
    } else {
      XCTFail("timeout")
    }
  }
  
  func testFlatten_InnerFailure() {
    func fail() throws -> Future<Int> { throw AsyncNinjaError.cancelled }
    let startTime = DispatchTime.now()
    let timeout = startTime + 0.7
    let future3D = future(after: 0.2) { return future(after: 0.3) { try fail() } }
    let future2D = future3D.flatten()
    if let failable = future2D.wait(timeout: timeout) {
      XCTAssertEqual(failable.failure! as? AsyncNinjaError, AsyncNinjaError.cancelled)
      let finishTime = DispatchTime.now()
      XCTAssert(startTime + 0.4 < finishTime)
      XCTAssert(startTime + 0.6 > finishTime)
    } else {
      XCTFail("timeout")
    }
  }
  
  func testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextAlive() {
    let actor = TestActor()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let futureValue = future(context: actor, after: 0.2) { (actor) -> Int in
      assert(actor: actor)
      expectation.fulfill()
      return try square_success(value)
    }

    usleep(150_000)
    XCTAssertNil(futureValue.value)

    self.waitForExpectations(timeout: 0.3)
    XCTAssertEqual(futureValue.success, square(value))
  }
  
  func testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextDead() {
    var actor: TestActor? = TestActor()
    let value = pickInt()

    let futureValue = future(context: actor!, after: 0.2) { (actor) -> Int in
      XCTFail()
      assert(actor: actor)
      return try square_success(value)
    }

    usleep(150_000)
    XCTAssertNil(futureValue.value)
    actor = nil

    usleep(250_000)
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
    usleep(100_000)
    XCTAssertEqual(futureValue.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }

  func testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextAlive() {
    let actor = TestActor()
    let value = pickInt()
    let expectation = self.expectation(description: "block called")

    let futureValue = future(context: actor, after: 0.2) { (actor) -> Int in
      assert(actor: actor)
      expectation.fulfill()
      return try square_failure(value)
    }

    usleep(150_000)
    XCTAssertNil(futureValue.value)

    self.waitForExpectations(timeout: 0.3)
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

    usleep(150_000)
    XCTAssertNil(futureValue.value)
    actor = nil

    usleep(250_000)
    XCTAssertEqual(futureValue.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
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
    usleep(100_000)
    XCTAssertEqual(futureValue.failure as? AsyncNinjaError, AsyncNinjaError.contextDeallocated)
  }

  func testGroupCompletionFuture() {
    let group = DispatchGroup()
    group.enter()
    let completionFuture = group.completionFuture

    usleep(100_000)
    XCTAssertNil(completionFuture.value)
    group.leave()

    usleep(100_000)
    XCTAssertNotNil(completionFuture.value)
  }
}
