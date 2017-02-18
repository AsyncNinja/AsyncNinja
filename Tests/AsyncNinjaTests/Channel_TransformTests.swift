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

class Channel_TransformTests: XCTestCase {
  
  static let allTests = [
    ("testDebounce", testDebounce),
    ("testDistinctInts", testDistinctInts),
//    ("testDistinctOptionalInts", testDistinctOptionalInts),
  ]

  func testDebounce() {
    let initalProducer = Producer<Int, String>()
    let derivedProducer = initalProducer.debounce(interval: 0.5)
    let expectation = self.expectation(description: "completion of derived producer")

    derivedProducer.extractAll { (numbers, stringOrError) in
      XCTAssertEqual([1, 6, 9, 12], numbers)
      XCTAssertEqual("Finished!", stringOrError.success!)
      expectation.fulfill()
    }

    DispatchQueue.global().async {
      usleep(100_000)
      initalProducer.update(1)
      initalProducer.update(2)
      initalProducer.update(3)
      usleep(250_000)
      initalProducer.update(4)
      initalProducer.update(5)
      initalProducer.update(6)
      usleep(250_000)
      initalProducer.update(7)
      initalProducer.update(8)
      initalProducer.update(9)
      usleep(1_000_000)
      initalProducer.update(10)
      initalProducer.update(11)
      initalProducer.update(12)
      usleep(200_000)
      initalProducer.succeed(with: "Finished!")
    }

    self.waitForExpectations(timeout: 5.0)
  }

  func testDistinctInts() {
    let updatable = Updatable<Int>()
    let expectation = self.expectation(description: "completion of producer")

    updatable.distinct().extractAll { (updates, completion) in
      XCTAssertEqual(updates, [1, 2, 3, 4, 5, 6, 7])
      expectation.fulfill()
    }

    let fixture = [1, 2, 2, 3, 3, 3, 4, 5, 6, 6, 7]
    DispatchQueue.global().async {
      updatable.update(fixture)
      updatable.succeed()
    }

    self.waitForExpectations(timeout: 1.0)
  }

//  func testDistinctOptionalInts() {
//    let updatable = Updatable<Int?>()
//    let expectation = self.expectation(description: "completion of producer")
//
//    updatable.distinct().extractAll { (updates, completion) in
//      let assumedResults = [nil, 1, nil, 2, 3, nil, 3, 4, 5, 6, 7]
//      XCTAssertEqual(updates.count, assumedResults.count)
//      for (update, result) in zip(updates, assumedResults) {
//        XCTAssertEqual(update, result)
//      }
//      expectation.fulfill()
//    }
//
//    let fixture = [nil, 1, nil, nil, 2, 2, 3, nil, 3, 3, 4, 5, 6, 6, 7]
//    DispatchQueue.global().async {
//      updatable.update(fixture)
//      updatable.succeed()
//    }
//
//    self.waitForExpectations(timeout: 1.0)
//  }
}
