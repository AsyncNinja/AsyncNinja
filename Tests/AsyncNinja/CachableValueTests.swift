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

class CachableValueTests: XCTestCase {

  static let allTests = [
    ("testSingleShotSuccess", testSingleShotSuccess),
    ("testSingleShotFailure", testSingleShotFailure),
    ("testMultiUseSuccess", testMultiUseSuccess),
    ("testMultiUseFailure", testMultiUseFailure)
    ]

  func testSingleShotSuccess() {
    multiTest {
      let value = pickInt()
      let holder = CachedValueHolder<Int> { _ in
        return future(after: 0.1) { value }
      }
      let futureA = holder.cachableValue.value()
      XCTAssertEqual(futureA.wait().maybeSuccess!, value)
      let futureB = holder.cachableValue.value()
      XCTAssertTrue(futureA === futureB)
    }
  }

  func testSingleShotFailure() {
    multiTest {
      let holder = CachedValueHolder<Int> { _ -> Future<Int> in
        return future(after: 0.1) { throw TestError.testCode }
      }
      let futureA = holder.cachableValue.value()
      XCTAssertEqual(futureA.wait().maybeFailure as? TestError, TestError.testCode)
      let futureB = holder.cachableValue.value()
      XCTAssertTrue(futureA === futureB)
    }
  }

  func testMultiUseSuccess() {
    multiTest {
      let firstValue = pickInt()
      var value = firstValue
      let holder = CachedValueHolder<Int> { _ in
        return future(after: 0.1) { value }
      }

      let futureA = holder.cachableValue.value()
      XCTAssertEqual(futureA.wait().maybeSuccess!, firstValue)

      let secondValue = pickInt()
      value = secondValue
      holder.cachableValue.invalidate()

      let futureB = holder.cachableValue.value()
      XCTAssertFalse(futureA === futureB)
      XCTAssertEqual(futureB.wait().maybeSuccess!, secondValue)
    }
  }

  func testMultiUseFailure() {
    multiTest {
      let firstError = TestError.testCode
      var error: Error
      error = firstError
      let holder = CachedValueHolder<Int> { _ in
        return future(after: 0.1) { throw error }
      }

      let futureA = holder.cachableValue.value()
      XCTAssertEqual(futureA.wait().maybeFailure as? TestError, firstError)

      let secondError = TestError.otherCode
      error = secondError
      holder.cachableValue.invalidate()

      let futureB = holder.cachableValue.value()
      XCTAssertFalse(futureA === futureB)
      XCTAssertEqual(futureB.wait().maybeFailure as? TestError, secondError)
    }
  }
}

private class CachedValueHolder<T>: ExecutionContext, ReleasePoolOwner {
  private(set) var cachableValue: SimpleCachableValue<T>!
  let executor = Executor.queue(DispatchQueue(label: "cached-value-holder-queue", target: .global()))
  let releasePool = ReleasePool()

  init(missHandler: @escaping (CachedValueHolder<T>) throws -> Future<T>) {
    self.cachableValue = SimpleCachableValue(context: self, missHandler: missHandler)
  }

  private func provideValue() -> Future<Int> {
    return future(after: 1.0) { 3 }
  }
}
