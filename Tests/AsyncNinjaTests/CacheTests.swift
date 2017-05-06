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

class CacheTests: XCTestCase {

  static let allTests = [
    ("testSingleShotFuture", testSingleShotFuture),
    ("testMultiShotFuture", testMultiShotFuture),
    ("testSingleShotFutureContextual", testSingleShotFutureContextual),
    ("testMultiShotFutureContextual", testMultiShotFutureContextual)
    ]

  func testSingleShotFuture() {
    multiTest {
      let cache: SimpleCache<String, Int?> = makeCache { (key) -> Future<Int?> in
        return future(after: 0.1) {
          () -> Int? in
          switch key {
          case "fail":
            throw TestError.testCode
          default:
            return Int(key)
          }
        }
      }

      let futureA1 = cache.value(forKey: "1")
      let futureA2 = cache.value(forKey: "1")
      let futureB = cache.value(forKey: "2")
      let futureC = cache.value(forKey: "C")
      let futureD = cache.value(forKey: "fail")
      XCTAssert(futureA1 === futureA2)
      XCTAssertEqual(futureA1.wait().success!, 1)
      XCTAssertEqual(futureB.wait().success!, 2)
      XCTAssertNil(futureC.wait().success!)
      XCTAssertEqual(futureD.wait().failure as! TestError, TestError.testCode)
    }
  }

  func testMultiShotFuture() {
    multiTest {
      var failCounter = 1
      let cache: SimpleCache<String, Int?> = makeCache { (key) -> Future<Int?> in
        return future(after: 0.1) {
          () -> Int? in
          switch key {
          case "fail" where failCounter > 0:
            failCounter -= 1
            throw TestError.testCode
          case "fail":
            return 777
          default:
            return Int(key)
          }
        }
      }

      let futureA1 = cache.value(forKey: "1")
      XCTAssertEqual(futureA1.wait().success!, 1)
      cache.invalidate(valueForKey: "1")
      let futureA2 = cache.value(forKey: "1")
      XCTAssertFalse(futureA1 === futureA2)
      XCTAssertEqual(futureA2.wait().success!, 1)
    }
  }

  class LocalActor: TestActor {
    var failCounter = 1
    func transformStringToInt(_ string: String) throws -> Int? {
      switch string {
      case "fail" where failCounter > 0:
        failCounter -= 1
        throw TestError.testCode
      case "fail":
        return 777
      default:
        return Int(string)
      }
    }
  }

  func testSingleShotFutureContextual() {
    multiTest {
      let actor = LocalActor()
      let cache: SimpleCache<String, Int?> = makeCache(context: actor) { (actor, key) -> Future<Int?> in
        return future(after: 0.1) {
          try actor.transformStringToInt(key)
        }
      }

      let futureA1 = cache.value(forKey: "1")
      let futureA2 = cache.value(forKey: "1")
      let futureB = cache.value(forKey: "2")
      let futureC = cache.value(forKey: "C")
      let futureD = cache.value(forKey: "fail")
      XCTAssert(futureA1 === futureA2)
      XCTAssertEqual(futureA1.wait().success!, 1)
      XCTAssertEqual(futureB.wait().success!, 2)
      XCTAssertNil(futureC.wait().success!)
      XCTAssertEqual(futureD.wait().failure as! TestError, TestError.testCode)
    }
  }

  func testMultiShotFutureContextual() {
    multiTest {
      let actor = LocalActor()
      let cache: SimpleCache<String, Int?> = makeCache(context: actor) { (actor, key) -> Future<Int?> in
        return future(after: 0.1) {
          try actor.transformStringToInt(key)
        }
      }

      let futureA1 = cache.value(forKey: "1")
      XCTAssertEqual(futureA1.wait().success!, 1)
      cache.invalidate(valueForKey: "1")
      let futureA2 = cache.value(forKey: "1")
      XCTAssertFalse(futureA1 === futureA2)
      XCTAssertEqual(futureA2.wait().success!, 1)
    }
  }
}
