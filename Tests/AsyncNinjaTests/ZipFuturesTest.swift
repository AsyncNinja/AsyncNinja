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

class ZipFuturesTest: XCTestCase {

  static let allTests = [
    ("test2Simple", test2Simple),
    ("test3Simple", test3Simple),
    ("test2Delayed", test2Delayed),
    ("test2Constant", test2Constant),
    ("test3Constant", test3Constant),
    ("test3Constant", test3Constants),
    ("test2Failure", test2Failure),
    ("test3Failure", test3Failure),
    ("test2Lifetime", test2Lifetime),
    ("test3Lifetime", test3Lifetime),
    ("testMerge2OfSameTypeFirst", testMerge2OfSameTypeFirst),
    ("testMerge2OfSameTypeSecond", testMerge2OfSameTypeSecond),
    ("testMerge3OfSameTypeFirst", testMerge3OfSameTypeFirst),
    ("testMerge3OfSameTypeSecond", testMerge3OfSameTypeSecond),
    ("testMerge3OfSameTypeThird", testMerge3OfSameTypeThird),
    ("testMerge2OfDifferentTypeFirst", testMerge2OfDifferentTypeFirst),
    ("testMerge2OfDifferentTypeSecond", testMerge2OfDifferentTypeSecond)
    ]

  func test2Simple() {
    let valueA = pickInt()
    let valueB = pickInt()
    let futureA = future(success: valueA)
    let futureB = future(success: valueB)
    let futureAB = zip(futureA, futureB)
    let valueAB = futureAB.wait().success!
    XCTAssertEqual(valueAB.0, valueA)
    XCTAssertEqual(valueAB.1, valueB)
  }

  func test3Simple() {
    let valueA = pickInt()
    let valueB = pickInt()
    let valueC = pickInt()
    let futureA = future(success: valueA)
    let futureB = future(success: valueB)
    let futureC = future(success: valueC)
    let futureABC = zip(futureA, futureB, futureC)
    let valueABC = futureABC.wait().success!
    XCTAssertEqual(valueABC.0, valueA)
    XCTAssertEqual(valueABC.1, valueB)
    XCTAssertEqual(valueABC.2, valueC)
  }

  func test2Delayed() {
    let valueA = pickInt()
    let valueB = pickInt()
    let futureA = future(after: 0.2) { valueA }
    let futureB = future(after: 0.3) { valueB }
    let futureAB = zip(futureA, futureB)
    let valueAB = futureAB.wait().success!
    XCTAssertEqual(valueAB.0, valueA)
    XCTAssertEqual(valueAB.1, valueB)
  }

  func test3Delayed() {
    let valueA = pickInt()
    let valueB = pickInt()
    let valueC = pickInt()
    let futureA = future(after: 0.2) { valueA }
    let futureB = future(after: 0.3) { valueB }
    let futureC = future(after: 0.4) { valueC }
    let futureABC = zip(futureA, futureB, futureC)
    let valueABC = futureABC.wait().success!
    XCTAssertEqual(valueABC.0, valueA)
    XCTAssertEqual(valueABC.1, valueB)
    XCTAssertEqual(valueABC.2, valueC)
  }

  func test2Constant() {
    let valueA = pickInt()
    let valueB = pickInt()
    let futureA = future(after: 0.2) { valueA }
    let futureAB = zip(futureA, valueB)
    let valueAB = futureAB.wait().success!
    XCTAssertEqual(valueAB.0, valueA)
    XCTAssertEqual(valueAB.1, valueB)
  }

  func test3Constant() {
    let valueA = pickInt()
    let valueB = pickInt()
    let valueC = pickInt()
    let futureA = future(after: 0.2) { valueA }
    let futureB = future(after: 0.3) { valueB }
    let futureABC = zip(futureA, futureB, valueC)
    let valueABC = futureABC.wait().success!
    XCTAssertEqual(valueABC.0, valueA)
    XCTAssertEqual(valueABC.1, valueB)
    XCTAssertEqual(valueABC.2, valueC)
  }

  func test3Constants() {
    let valueA = pickInt()
    let valueB = pickInt()
    let valueC = pickInt()
    let futureA = future(after: 0.2) { valueA }
    let futureABC = zip(futureA, valueB, valueC)
    let valueABC = futureABC.wait().success!
    XCTAssertEqual(valueABC.0, valueA)
    XCTAssertEqual(valueABC.1, valueB)
    XCTAssertEqual(valueABC.2, valueC)
  }

  func test2Failure() {
    let startTime = DispatchTime.now()
    let valueA = pickInt()
    let futureA = future(after: 0.4) { valueA }
    let futureB = future(after: 0.2) { throw TestError.testCode  }
    let futureAB = zip(futureA, futureB)
    XCTAssertEqual(futureAB.wait().failure as! TestError, TestError.testCode)
    XCTAssert(DispatchTime.now() > startTime + 0.2)
    XCTAssert(DispatchTime.now() < startTime + 0.4)
  }

  func test3Failure() {
    let startTime = DispatchTime.now()
    let valueA = pickInt()
    let valueC = pickInt()
    let futureA = future(after: 0.2) { valueA }
    let futureB = future(after: 0.3) { throw TestError.testCode  }
    let futureC = future(after: 0.4) { valueC }
    let futureABC = zip(futureA, futureB, futureC)
    XCTAssertEqual(futureABC.wait().failure as! TestError, TestError.testCode)
    let finishTime = DispatchTime.now()
    XCTAssert(finishTime > startTime + 0.2)
    XCTAssert(finishTime < startTime + 0.4)
  }

  func test2Lifetime() {
    let valueA = pickInt()
    let valueB = pickInt()
    var futureA: Future<Int>? = future(after: 2.0) { XCTFail(); return valueA }
    weak var weakFutureA = futureA
    var futureB: Future<Int>? = future(after: 3.0) { XCTFail(); return valueB }
    weak var weakFutureB = futureB
    var futureAB: Future<(Int, Int)>? = zip(futureA!, futureB!)
    weak var weakFutureAB = futureAB
    futureA = nil
    futureB = nil

    XCTAssertNotNil(weakFutureA)
    XCTAssertNotNil(weakFutureB)
    XCTAssertNotNil(weakFutureAB)

    futureAB = nil

    XCTAssertNil(weakFutureA)
    XCTAssertNil(weakFutureB)
    XCTAssertNil(weakFutureAB)

    sleep(1)
  }

  func test3Lifetime() {
    let valueA = pickInt()
    let valueB = pickInt()
    let valueC = pickInt()
    var futureA: Future<Int>? = future(after: 0.2) { XCTFail(); return valueA }
    weak var weakFutureA = futureA
    var futureB: Future<Int>? = future(after: 0.3) { XCTFail(); return valueB }
    weak var weakFutureB = futureB
    var futureC: Future<Int>? = future(after: 0.4) { XCTFail(); return valueC }
    weak var weakFutureC = futureC
    var futureABC: Future<(Int, Int, Int)>? = zip(futureA!, futureB!, futureC!)
    weak var weakFutureABC = futureABC
    futureA = nil
    futureB = nil
    futureC = nil

    XCTAssertNotNil(weakFutureA)
    XCTAssertNotNil(weakFutureB)
    XCTAssertNotNil(weakFutureC)
    XCTAssertNotNil(weakFutureABC)

    futureABC = nil

    XCTAssertNil(weakFutureA)
    XCTAssertNil(weakFutureB)
    XCTAssertNil(weakFutureC)
    XCTAssertNil(weakFutureABC)

    sleep(1)
  }

  func testMerge2OfSameTypeFirst() {
    let futureA: Future<String> = future(after: 0.1) { return "Right" }
    let futureB: Future<String> = future(after: 0.3) { return "Wrong" }
    XCTAssertEqual(merge(futureA, futureB).wait().success, "Right")
  }

  func testMerge2OfSameTypeSecond() {
    let futureA: Future<String> = future(after: 0.3) { return "Wrong" }
    let futureB: Future<String> = future(after: 0.1) { return "Right" }
    XCTAssertEqual(merge(futureA, futureB).wait().success, "Right")
  }

  func testMerge3OfSameTypeFirst() {
    let futureA: Future<String> = future(after: 0.1) { return "Right" }
    let futureB: Future<String> = future(after: 0.3) { return "Wrong" }
    let futureC: Future<String> = future(after: 0.5) { return "Wrong 2" }
    XCTAssertEqual(merge(futureA, futureB, futureC).wait().success, "Right")
  }

  func testMerge3OfSameTypeSecond() {
    let futureA: Future<String> = future(after: 0.3) { return "Wrong" }
    let futureB: Future<String> = future(after: 0.1) { return "Right" }
    let futureC: Future<String> = future(after: 0.5) { return "Wrong 2" }
    XCTAssertEqual(merge(futureA, futureB, futureC).wait().success, "Right")
  }

  func testMerge3OfSameTypeThird() {
    let futureA: Future<String> = future(after: 0.3) { return "Wrong" }
    let futureB: Future<String> = future(after: 0.5) { return "Wrong 2" }
    let futureC: Future<String> = future(after: 0.1) { return "Right" }
    XCTAssertEqual(merge(futureA, futureB, futureC).wait().success, "Right")
  }

  func testMerge2OfDifferentTypeFirst() {
    let futureA: Future<String> = future(after: 0.1) { return "Right" }
    let futureB: Future<Int> = future(after: 0.3) { return 0xbad }
    XCTAssert(merge(futureA, futureB).wait().success! == .left("Right"))
  }

  func testMerge2OfDifferentTypeSecond() {
    let futureA: Future<Int> = future(after: 0.3) { return 0xbad }
    let futureB: Future<String> = future(after: 0.1) { return "Right" }
    XCTAssert(merge(futureA, futureB).wait().success! == .right("Right"))
  }
}
