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

class EventSource_FlatMapFuturesTests: XCTestCase {
  
  static let allTests = [
    ("testFlatMapFutures_KeepUnordered", testFlatMapFutures_KeepUnordered),
    ("testFlatMapFutures_KeepLatestTransform", testFlatMapFutures_KeepLatestTransform),
    ("testFlatMapFutures_DropResultsOutOfOrder", testFlatMapFutures_DropResultsOutOfOrder),
    ("testFlatMapFutures_OrderResults", testFlatMapFutures_OrderResults),
    ("testFlatMapFutures_TransformSerially", testFlatMapFutures_TransformSerially),
  ]

  func _testFlatMapFutures(behavior: ChannelFlatteningBehavior, expectedResults: [String],
                          file: StaticString = #file, line: UInt = #line) {
    let producerA = Producer<(duration: Double, name: String), String>()
    let qos = pickQoS()
    let channelB = producerA.flatMap(executor: .queue(qos), behavior: behavior) { (duration, name) -> Future<String> in
      assert(qos: qos)
      return future(after: duration) {
        return "t(\(name))"
      }
    }

    let zipped = zip(expectedResults, channelB)
    DispatchQueue.global().async {
      let sema = DispatchSemaphore(value: 0)
      producerA.update((duration: 0.1, name: "x"))
      let _ = sema.wait(timeout: DispatchTime.now() + .milliseconds(10))
      sema.signal()

      producerA.update((duration: 0.3, name: "y"))
      let _ = sema.wait(timeout: DispatchTime.now() + .milliseconds(10))
      sema.signal()

      producerA.update((duration: 0.2, name: "z"))
      let _ = sema.wait(timeout: DispatchTime.now() + .milliseconds(10))
      sema.signal()

      producerA.update((duration: 0.5, name: "done"))
      let _ = sema.wait(timeout: DispatchTime.now() + .milliseconds(10))
      sema.signal()
    }

    var count = 0
    for (expectedResult, update) in zipped {
      XCTAssertEqual(update, expectedResult, file: file, line: line)
      count += 1
    }

    XCTAssertEqual(count, expectedResults.count, file: file, line: line)
  }

  func testFlatMapFutures_KeepUnordered() {
    multiTest {
      self._testFlatMapFutures(behavior: .keepUnordered, expectedResults: ["t(x)", "t(z)", "t(y)", "t(done)"])
    }
  }

  func testFlatMapFutures_KeepLatestTransform() {
    multiTest {
      self._testFlatMapFutures(behavior: .keepLatestTransform, expectedResults: ["t(done)"])
    }
  }

  func testFlatMapFutures_DropResultsOutOfOrder() {
    multiTest {
      self._testFlatMapFutures(behavior: .dropResultsOutOfOrder, expectedResults: ["t(x)", "t(z)", "t(done)"])
    }
  }

  func testFlatMapFutures_OrderResults() {
    multiTest {
      self._testFlatMapFutures(behavior: .orderResults, expectedResults: ["t(x)", "t(y)", "t(z)", "t(done)"])
    }
  }

  func testFlatMapFutures_TransformSerially() {
    multiTest {
      self._testFlatMapFutures(behavior: .transformSerially, expectedResults: ["t(x)", "t(y)", "t(z)", "t(done)"])
    }
  }
}
