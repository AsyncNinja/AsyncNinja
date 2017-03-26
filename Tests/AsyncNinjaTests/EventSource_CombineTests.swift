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

class EventSource_CombineTests: XCTestCase {
  
  static let allTests = [
    ("testSample", testSample),
  ]

  func testSample() {
    let producerOfOdds = Producer<Int, String>()
    let producerOfEvents = Producer<Int, String>()
    let channelOfNumbers = producerOfOdds.sample(with: producerOfEvents)
    let expectation = self.expectation(description: "async checks to finish")

    channelOfNumbers.extractAll().onSuccess { (pairs, stringsOfError) in
      let fixturePairs = [
        (3, 2),
        (5, 6),
        (7, 8)
      ]

      XCTAssertEqual(pairs.count, fixturePairs.count)
      for (resultPair, fixturePair) in zip(pairs.sorted { $0.0 < $1.0 }, fixturePairs) {
        XCTAssertEqual(resultPair.0, fixturePair.0)
        XCTAssertEqual(resultPair.1, fixturePair.1)
      }

      XCTAssertEqual(stringsOfError.success!.0, "Hello")
      XCTAssertEqual(stringsOfError.success!.1, "World")
      expectation.fulfill()
    }

    DispatchQueue.global().async {
      usleep(100_000)
      producerOfOdds.update(1)
      producerOfOdds.update(3)
      producerOfEvents.update(2)
      producerOfEvents.update(4)
      producerOfOdds.update(5)
      producerOfEvents.update(6)
      producerOfOdds.update(7)
      producerOfOdds.succeed("Hello")
      producerOfEvents.update(8)
      producerOfEvents.succeed("World")
    }

    self.waitForExpectations(timeout: 1.0, handler: nil)
  }
}
