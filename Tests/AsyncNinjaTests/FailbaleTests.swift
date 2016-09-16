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

class FallibleTests : XCTestCase {
  enum TestError : Error {
    case testCode
    case otherCode
  }

  func testSuccess() {
    let value = Fallible(success: 3)
    XCTAssertEqual(3, value.success)
    XCTAssertNil(value.failure)
  }

  func testFailure() {
    let value = Fallible<Int>(failure: TestError.testCode)
    XCTAssertEqual(TestError.testCode, value.failure as! TestError)
    XCTAssertNil(value.success)
  }

  func testOnSuccess() {
    let value = Fallible(success: 1)
    var numberOfCalls = 0

    value.onSuccess {
      XCTAssertEqual(1, $0)
      numberOfCalls += 1
    }

    XCTAssertEqual(1, numberOfCalls)
  }

  func testOnFailure() {
    let value = Fallible<Int>(failure: TestError.testCode)
    var numberOfCalls = 0

    value.onFailure {
      XCTAssertEqual(TestError.testCode, $0 as! TestError)
      numberOfCalls += 1
    }

    XCTAssertEqual(1, numberOfCalls)
  }

  func testMapSuccessForSuccess() {
    let value = Fallible<Int>(success: 2)
    var numberOfCalls = 0

    let nextValue = value.mapSuccess { (success) -> Int in
      numberOfCalls += 1
      return success * 3
    }

    XCTAssertEqual(nextValue.success!, 6)
    XCTAssertEqual(numberOfCalls, 1)
  }

  func testMapSuccessForFailure() {
    let value = Fallible<Int>(failure: TestError.testCode)
    var numberOfCalls = 0

    let nextValue = value.mapSuccess { (success) -> Int in
      numberOfCalls += 1
      return success * 3
    }

    XCTAssertEqual(nextValue.failure as! TestError, TestError.testCode)
    XCTAssertEqual(numberOfCalls, 0)
  }

  func testMapSuccessForThrow() {
    let value = Fallible<Int>(success: 2)
    var numberOfCalls = 0

    let nextValue = value.mapSuccess { (success) -> Int in
      numberOfCalls += 1
      throw TestError.testCode
    }

    XCTAssertEqual(nextValue.failure as! TestError, TestError.testCode)
    XCTAssertEqual(numberOfCalls, 1)
  }

  func testMapFailureForSuccess() {
    let value = Fallible(success: 2)
    var numberOfCalls = 0

    let nextValue = value.mapFailure { _ in
      numberOfCalls += 1
      return 3
    }

    XCTAssertEqual(nextValue, 2)
    XCTAssertEqual(numberOfCalls, 0)
  }

  func testMapFailureOnFailure() {
    let value = Fallible<Int>(failure: TestError.testCode)
    var numberOfCalls = 0

    let nextValue = value.mapFailure { _ in
      numberOfCalls += 1
      return 3
    }

    XCTAssertEqual(nextValue, 3)
    XCTAssertEqual(numberOfCalls, 1)
  }

  func testMapFailure2OnSuccess() {
    let value = Fallible(success: 2)
    var numberOfCalls = 0

    let nextValue = value.mapFailure { _ in
      try procedureThatCanThrow()
      numberOfCalls += 1
      return 3
    }

    XCTAssertEqual(nextValue.success!, 2)
    XCTAssertEqual(numberOfCalls, 0)
  }

  func testMapFailure2OnFailure() {
    let value = Fallible<Int>(failure: TestError.testCode)
    var numberOfCalls = 0

    let nextValue = value.mapFailure { _ in
      try procedureThatCanThrow()
      numberOfCalls += 1
      return 3
    }

    XCTAssertEqual(nextValue.success!, 3)
    XCTAssertEqual(numberOfCalls, 1)
  }

  func testMapFailure2OnThrow() {
    let value = Fallible<Int>(failure: TestError.testCode)
    var numberOfCalls = 0

    let nextValue = value.mapFailure { _ in
      numberOfCalls += 1
      throw TestError.otherCode
    }

    XCTAssertEqual(nextValue.failure as! TestError, TestError.otherCode)
    XCTAssertEqual(numberOfCalls, 1)
  }

  func testMakeFallibleSuccess() {
    let value = fallible { 2 }
    XCTAssertEqual(value.success!, 2)
  }

  func testMakeFallibleFailure() {
    let value = fallible { throw TestError.testCode }
    XCTAssertEqual(value.failure as! TestError, TestError.testCode)
  }
}

fileprivate func procedureThatCanThrow() throws {

}
