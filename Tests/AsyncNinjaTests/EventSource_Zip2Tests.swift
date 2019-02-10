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

class EventSource_Zip2Tests: XCTestCase {

  static let allTests = [
    ("testZip", testZip)
  ]

  func testZip() {
    let producerOfOdds = Producer<Int, String>()
    let producerOfEvents = Producer<Int, String>()
    let expectation = self.expectation(description: "channel to finish")

    zip(producerOfOdds, producerOfEvents)
      .extractAll().onSuccess {
        let (pairs, stringsOfError) = $0
        let fixturePairs = [(1, 2), (3, 4), (5, 6), (7, 8)]
        XCTAssertEqual(fixturePairs.count, pairs.count)
        for (pair, fixturePair) in zip(pairs, fixturePairs) {
          XCTAssertEqual(pair.0, fixturePair.0)
          XCTAssertEqual(pair.1, fixturePair.1)
        }

        XCTAssertEqual(stringsOfError.maybeSuccess!.0, "Hello")
        XCTAssertEqual(stringsOfError.maybeSuccess!.1, "World")
        expectation.fulfill()
    }

    DispatchQueue.global().async {
      producerOfOdds.update(1)
      producerOfOdds.update(3)
      producerOfEvents.update(2)
      producerOfEvents.update(4)
      producerOfOdds.update(5)
      producerOfEvents.update(6)
      producerOfOdds.update(7)
      producerOfOdds.succeed("Hello")
      producerOfEvents.update(8)
      producerOfEvents.update(10)
      producerOfEvents.succeed("World")
    }

    self.waitForExpectations(timeout: 1.0)
  }
}
