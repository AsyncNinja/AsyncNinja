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

class FallibleTests: XCTestCase {
  static let allTests = [
    ("testSuccess", testSuccess),
    ("testFailure", testFailure),
    ("testOnSuccess", testOnSuccess),
    ("testOnFailure", testOnFailure),
    ("testFlattenSuccessSuccess", testFlattenSuccessSuccess),
    ("testFlattenSuccessFailure", testFlattenSuccessFailure),
    ("testFlattenFailure", testFlattenFailure),
    ("testMapSuccessForSuccess", testMapSuccessForSuccess),
    ("testMapSuccessForFailure", testMapSuccessForFailure),
    ("testMapSuccessForThrow", testMapSuccessForThrow),
    ("testMapFailureForSuccess", testMapFailureForSuccess),
    ("testMapFailureOnFailure", testMapFailureOnFailure),
    ("testMapFailure2OnSuccess", testMapFailure2OnSuccess),
    ("testMapFailure2OnFailure", testMapFailure2OnFailure),
    ("testMapFailure2OnThrow", testMapFailure2OnThrow),
    ("testMakeFallibleSuccess", testMakeFallibleSuccess),
    ("testMakeFallibleFailure", testMakeFallibleFailure),
    ("testZip2_SuccessSuccess", testZip2_SuccessSuccess),
    ("testZip2_SuccessFailure", testZip2_SuccessFailure),
    ("testZip2_FailureSuccess", testZip2_FailureSuccess),
    ("testZip2_FailureFailure", testZip2_FailureFailure),
    ("testDescription", testDescription)
    ]

  func testSuccess() {
    let value: Fallible<Int> = .success(3)
    XCTAssertEqual(3, value.maybeSuccess)
    XCTAssertNil(value.maybeFailure)
  }

  func testFailure() {
    let value: Fallible<Int> = .failure(TestError.testCode)
    XCTAssertEqual(TestError.testCode, value.maybeFailure as! TestError)
    XCTAssertNil(value.maybeSuccess)
  }

  func testOnSuccess() {
    let value: Fallible<Int> = .success(1)
    var numberOfCalls = 0

    value.onSuccess {
      XCTAssertEqual(1, $0)
      numberOfCalls += 1
    }

    XCTAssertEqual(1, numberOfCalls)
  }

  func testOnFailure() {
    let value: Fallible<Int> = .failure(TestError.testCode)
    var numberOfCalls = 0

    value.onFailure {
      XCTAssertEqual(TestError.testCode, $0 as! TestError)
      numberOfCalls += 1
    }

    XCTAssertEqual(1, numberOfCalls)
  }

  func testFlattenSuccessSuccess() {
    let intValue = pickInt()
    let fallible2dInt: Fallible<Fallible<Int>> = .success(.success(intValue))
    let fallible1dInt: Fallible<Int> = fallible2dInt.flatten()

    XCTAssertEqual(fallible1dInt.maybeSuccess, intValue)
  }

  func testFlattenSuccessFailure() {
    let fallible2dInt: Fallible<Fallible<Int>> = .success(.failure(TestError.testCode))
    let fallible1dInt: Fallible<Int> = fallible2dInt.flatten()

    XCTAssertEqual(fallible1dInt.maybeFailure as? TestError, TestError.testCode)
  }

  func testFlattenFailure() {
    let fallible2dInt: Fallible<Fallible<Int>> = .failure(TestError.testCode)
    let fallible1dInt: Fallible<Int> = fallible2dInt.flatten()

    XCTAssertEqual(fallible1dInt.maybeFailure as? TestError, TestError.testCode)
  }

  func testMapSuccessForSuccess() {
    let value: Fallible<Int> = .success(2)
    var numberOfCalls = 0

    let nextValue = value.map { (success) -> Int in
      numberOfCalls += 1
      return success * 3
    }

    XCTAssertEqual(nextValue.maybeSuccess, 6)
    XCTAssertEqual(numberOfCalls, 1)
  }

  func testMapSuccessForFailure() {
    let value: Fallible<Int> = .failure(TestError.testCode)
    var numberOfCalls = 0

    let nextValue = value.map { (success) -> Int in
      numberOfCalls += 1
      return success * 3
    }

    XCTAssertEqual(nextValue.maybeFailure as! TestError, TestError.testCode)
    XCTAssertEqual(numberOfCalls, 0)
  }

  func testMapSuccessForThrow() {
    let value: Fallible<Int> = .success(2)
    var numberOfCalls = 0

    let nextValue = value.map { _ -> Int in
      numberOfCalls += 1
      throw TestError.testCode
    }

    XCTAssertEqual(nextValue.maybeFailure as! TestError, TestError.testCode)
    XCTAssertEqual(numberOfCalls, 1)
  }

  func testMapFailureForSuccess() {
    let value: Fallible = .success(2)
    var numberOfCalls = 0

    let nextValue = value.recover { _ in
      numberOfCalls += 1
      return 3
    }

    XCTAssertEqual(nextValue, 2)
    XCTAssertEqual(numberOfCalls, 0)
  }

  func testMapFailureOnFailure() {
    let value: Fallible<Int> = .failure(TestError.testCode)
    var numberOfCalls = 0

    let nextValue = value.recover { _ in
      numberOfCalls += 1
      return 3
    }

    XCTAssertEqual(nextValue, 3)
    XCTAssertEqual(numberOfCalls, 1)
  }

  func testMapFailure2OnSuccess() {
    let value: Fallible<Int> = .success(2)
    var numberOfCalls = 0

    let nextValue = value.tryRecover { _ in
      try procedureThatCanThrow()
      numberOfCalls += 1
      return 3
    }

    XCTAssertEqual(nextValue.maybeSuccess, 2)
    XCTAssertEqual(numberOfCalls, 0)
  }

  func testMapFailure2OnFailure() {
    let value: Fallible<Int> = .failure(TestError.testCode)
    var numberOfCalls = 0

    let nextValue = value.tryRecover { _ in
      try procedureThatCanThrow()
      numberOfCalls += 1
      return 3
    }

    XCTAssertEqual(nextValue.maybeSuccess, 3)
    XCTAssertEqual(numberOfCalls, 1)
  }

  func testMapFailure2OnThrow() {
    let value: Fallible<Int> = .failure(TestError.testCode)
    var numberOfCalls = 0

    let nextValue = value.tryRecover { _ in
      numberOfCalls += 1
      throw TestError.otherCode
    }

    XCTAssertEqual(nextValue.maybeFailure as! TestError, TestError.otherCode)
    XCTAssertEqual(numberOfCalls, 1)
  }

  func testMakeFallibleSuccess() {
    let value = fallible { 2 }
    XCTAssertEqual(value.maybeSuccess, 2)
  }

  func testMakeFallibleFailure() {
    let value = fallible { throw TestError.testCode }
    XCTAssertEqual(value.maybeFailure as! TestError, TestError.testCode)
  }

  func testZip2_SuccessSuccess() {
    let fallibleA: Fallible<Int> = .success(1)
    let fallibleB: Fallible<String> = .success("a")
    let fallibleResult = zip(fallibleA, fallibleB)
    XCTAssertEqual(1, fallibleResult.maybeSuccess!.0)
    XCTAssertEqual("a", fallibleResult.maybeSuccess!.1)
  }

  func testZip2_SuccessFailure() {
    let fallibleA: Fallible<Int> = .success(1)
    let fallibleB: Fallible<String> = .failure(TestError.otherCode)
    let fallibleResult = zip(fallibleA, fallibleB)
    XCTAssertEqual(TestError.otherCode, fallibleResult.maybeFailure as! TestError)
  }

  func testZip2_FailureSuccess() {
    let fallibleA: Fallible<Int> = .failure(TestError.testCode)
    let fallibleB: Fallible<String> = .success("a")
    let fallibleResult = zip(fallibleA, fallibleB)
    XCTAssertEqual(TestError.testCode, fallibleResult.maybeFailure as! TestError)
  }

  func testZip2_FailureFailure() {
    let fallibleA: Fallible<Int> = .failure(TestError.testCode)
    let fallibleB: Fallible<String> = .failure(TestError.otherCode)
    let fallibleResult = zip(fallibleA, fallibleB)
    XCTAssertEqual(TestError.testCode, fallibleResult.maybeFailure as! TestError)
  }

  func testDescription() {
    let fallibleA: Fallible<Int> = .success(1)
    XCTAssertEqual("success(1)", fallibleA.description)
    XCTAssertEqual("success<Int>(1)", fallibleA.debugDescription)
    let fallibleB: Fallible<Int> = .failure(TestError.testCode)
    XCTAssertEqual("failure(testCode)", fallibleB.description)
    XCTAssertEqual("failure<Int>(testCode)", fallibleB.debugDescription)
  }
}

private func procedureThatCanThrow() throws {

}
