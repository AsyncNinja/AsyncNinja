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

class FutureTests : XCTestCase {

  func testLifetime() {

    weak var weakFuture: Future<Int>?
    weak var weakMappedFuture: Future<Int>?

    let result: Int = autoreleasepool {
      let futureValue = future(value: 1)
      let mappedFutureValue = futureValue.map(executor: .utility) { (value) -> Int in
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
          assert(qos: .utility)
        }
        return value * 3
      }
      weakFuture = futureValue
      weakMappedFuture = mappedFutureValue
      return mappedFutureValue.wait()
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
      
      let result1 = future(value: 1)
        .map(executor: .userInteractive, transform: makePerformer(globalQOS: .userInteractive, multiplier: 2))
        .map(executor: .default, transform: makePerformer(globalQOS: .default, multiplier: 3))
        .map(executor: .utility, transform: makePerformer(globalQOS: .utility, multiplier: 4))
        .map(executor: .background, transform: makePerformer(globalQOS: .background, multiplier: 5))

      let result2 = future(value: 2)
        .map(executor: .background, transform: makePerformer(globalQOS: .background, multiplier: 5))
        .map(executor: .utility, transform: makePerformer(globalQOS: .utility, multiplier: 4))
        .map(executor: .default, transform: makePerformer(globalQOS: .default, multiplier: 3))
        .map(executor: .userInteractive, transform: makePerformer(globalQOS: .userInteractive, multiplier: 2))
      
      let result = zip(result1, result2).map { $0 + $1 }.wait()

      XCTAssertEqual(result, 360)
    }
  }

  func testMapFinalToFinal() {
    let transformExpectation = self.expectation(description: "transform called")
    let qos = pickQoS()
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
    let valueSquared = square(value)

    let mappedFuture: Future<Int> = autoreleasepool {
      let initialFuture = future(value: value)
      weakInitialFuture = initialFuture
      return initialFuture
        .map(executor: .queue(qos)) {
          assert(qos: qos)
          transformExpectation.fulfill()
          return square($0)
      }
    }

    self.waitForExpectations(timeout: 0.1)
    let result = mappedFuture.wait()
    XCTAssertNil(weakInitialFuture)
    XCTAssertEqual(result, valueSquared)
  }

  func testMapFinalToFallibleFinal_Success() {
    let transformExpectation = self.expectation(description: "transform called")
    let qos = pickQoS()
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
    let valueSquared = square(value)

    let mappedFuture: FallibleFuture<Int> = autoreleasepool {
      let initialFuture = future(value: value)
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

  func testMapFinalToFallibleFinal_Failure() {
    let transformExpectation = self.expectation(description: "transform called")
    let qos = pickQoS()
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
//    let valueSquared = square(value)

    let mappedFuture: FallibleFuture<Int> = autoreleasepool {
      let initialFuture = future(value: value)
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

  func testMapContextualFinalToFinal_Success_ContextAlive() {
    let actor = TestActor()
    let transformExpectation = self.expectation(description: "transform called")
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
    let valueSquared = square(value)

    let mappedFuture: FallibleFuture<Int> = autoreleasepool {
      let initialFuture = future(value: value)
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

  func testMapContextualFinalToFinal_Success_ContextDead() {
//    let transformExpectation = self.expectation(description: "transform called")
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
//    let valueSquared = square(value)

    let mappedFuture: FallibleFuture<Int> = autoreleasepool {
      let initialFuture = future(value: value)
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
    XCTAssertEqual(result.failure as? ConcurrencyError, .contextDeallocated)
  }

  func testMapContextualFinalToFinal_Failure_ContextAlive() {
    let actor = TestActor()
    let transformExpectation = self.expectation(description: "transform called")
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
    //let valueSquared = square(value)

    let mappedFuture: FallibleFuture<Int> = autoreleasepool {
      let initialFuture = future(value: value)
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

  func testMapContextualFinalToFinal_Failure_ContextDead() {
    //let transformExpectation = self.expectation(description: "transform called")
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()
    //let valueSquared = square(value)

    let mappedFuture: FallibleFuture<Int> = autoreleasepool {
      let initialFuture = future(value: value)
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
    XCTAssertEqual(result.failure as? ConcurrencyError, .contextDeallocated)
  }

  func testOnValueContextual_ContextAlive() {
    let actor = TestActor()
    let transformExpectation = self.expectation(description: "transform called")
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()

    autoreleasepool {
      let initialFuture = future(value: value)
      weakInitialFuture = initialFuture
      initialFuture.onValue(context: actor) { (actor, value_) in
        assert(actor: actor)
        XCTAssertEqual(value, value_)
        transformExpectation.fulfill()
      }
    }

    self.waitForExpectations(timeout: 0.1)
    XCTAssertNil(weakInitialFuture)
  }

  func testOnValueContextual_ContextDead() {
    weak var weakInitialFuture: Future<Int>?
    let value = pickInt()

    autoreleasepool {
      let actor = TestActor()
      let initialFuture = future(value: value)
      weakInitialFuture = initialFuture
      initialFuture
        .delayed(timeout: 0.1)
        .onValue(context: actor) { (actor, value_) in
          XCTFail()
          assert(actor: actor)
      }
    }

    sleep(1)
    XCTAssertNil(weakInitialFuture)
  }

  // Test: FutureTests.testOnValueContextual_ContextAlive
  // Test: FutureTests.testOnValueContextual_ContextDead

}
