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

class ZipFuturesTest : XCTestCase {
  
  static let allTests = [
    ("test2Simple", test2Simple),
    ("test2Delayed", test2Delayed),
    ("test2Constant", test2Constant),
    ("test2Failure", test2Failure),
    ("test2Lifetime", test2Lifetime),
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
  
  func test2Constant() {
    let valueA = pickInt()
    let valueB = pickInt()
    let futureA = future(after: 0.2) { valueA }
    let futureAB = zip(futureA, valueB)
    let valueAB = futureAB.wait().success!
    XCTAssertEqual(valueAB.0, valueA)
    XCTAssertEqual(valueAB.1, valueB)
  }
  
  func test2Failure() {
    let startTime = DispatchTime.now()
    let valueA = pickInt()
    let futureA = future(after: 0.2) { valueA }
    let futureB: Future<Int> = future(failure: TestError.testCode)
    let futureAB = zip(futureA, futureB)
    XCTAssertEqual(futureAB.wait().failure as! TestError, TestError.testCode)
    XCTAssert(DispatchTime.now() < startTime + 0.1) // early finish
  }
  
  func test2Lifetime() {
    let valueA = pickInt()
    let valueB = pickInt()
    var futureA: Future<Int>? = future(after: 0.2) { XCTFail(); return valueA }
    weak var weakFutureA = futureA
    var futureB: Future<Int>? = future(after: 0.3) { XCTFail(); return valueB }
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
  }
}
