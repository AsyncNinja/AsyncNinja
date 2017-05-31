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

class PerformanceTests: XCTestCase {
  static let allTests = [
    ("testConstantFutureWait", testConstantFutureWait),
    ("testMappedFutureWait_Success", testMappedFutureWait_Success),
    ("testMappedFutureWait_Failure", testMappedFutureWait_Failure),
    ("testHugeMapping_Success", testHugeMapping_Success),
    ("testHugeMapping_Failure", testHugeMapping_Failure),
    ("testPerformanceFuture", testPerformanceFuture)
    ]

  static let runsRange: CountableRange<Int64> = 0..<100000

  func testConstantFutureWait() {
    self.measure {
        for value in PerformanceTests.runsRange {
            let futureValue = future(success: value)
            XCTAssertEqual(futureValue.wait().success, value)
        }
    }
  }

  func testMappedFutureWait_Success() {
    self.measure {
      for value in PerformanceTests.runsRange {
        let futureValue = future(success: value).map(executor: .immediate) { $0 * 2 }
        XCTAssertEqual(futureValue.wait().success, value * 2)
      }
    }
  }

  func testMappedFutureWait_Failure() {
    self.measure {
      for value in PerformanceTests.runsRange {
        let futureValue = future(success: value).map(executor: .immediate) { _ in throw TestError.testCode }
        let failure = futureValue.wait().failure as! TestError
        XCTAssertEqual(failure, TestError.testCode)
      }
    }
  }

  func testHugeMapping_Success() {
    self.measure {
      var futureValue: Future<Int64> = future(success: 0)
      for _ in PerformanceTests.runsRange {
        futureValue = futureValue.map(executor: .immediate) { $0 + 1 }
      }

      XCTAssertEqual(futureValue.wait().success, PerformanceTests.runsRange.upperBound)
    }
  }

  func testHugeMapping_Failure() {
    self.measure {
      var futureValue: Future<Int64> = future(failure: TestError.testCode)
      for _ in PerformanceTests.runsRange {
        futureValue = futureValue.map(executor: .immediate) { $0 + 1 }
      }

      XCTAssertEqual(futureValue.wait().failure as! TestError, TestError.testCode)
    }
  }

  func testReduce() {
    func asyncTransform(value: Int64) -> Future<Int64> {
      return future { value * 2 }
    }

    self.measure {
      let resultValue = PerformanceTests.runsRange
        .map(asyncTransform)
        .asyncReduce(0, +)
        .wait().success!
      let fixture = (PerformanceTests.runsRange.lowerBound + PerformanceTests.runsRange.upperBound - 1)
        * Int64(PerformanceTests.runsRange.count)
      XCTAssertEqual(resultValue, fixture)
    }
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
        .map(executor: .userInteractive, makePerformer(globalQOS: .userInteractive, multiplier: 2))
        .map(executor: .default, makePerformer(globalQOS: .default, multiplier: 3))
        .map(executor: .utility, makePerformer(globalQOS: .utility, multiplier: 4))
        .map(executor: .background, makePerformer(globalQOS: .background, multiplier: 5))

      let result2 = future(success: 2)
        .map(executor: .background, makePerformer(globalQOS: .background, multiplier: 5))
        .map(executor: .utility, makePerformer(globalQOS: .utility, multiplier: 4))
        .map(executor: .default,
             makePerformer(globalQOS: .default, multiplier: 3))
        .map(executor: .userInteractive, makePerformer(globalQOS: .userInteractive, multiplier: 2))

      let result = zip(result1, result2)
        .map { $0.0 + $0.1 }
        .wait().success!

      XCTAssertEqual(result, 360)
    }
  }
}
