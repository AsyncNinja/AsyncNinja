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

class Channel_MapTests: XCTestCase {
  
  static let allTests = [
    ("testMapPeriodic", testMapPeriodic),
    ("testFilterPeriodic", testFilterPeriodic),
  ]

  func makeChannel<S: Sequence, T>(periodics: S, success: T) -> Channel<S.Iterator.Element, T> {
    let producer = Producer<S.Iterator.Element, T>()

    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
      producer.send(periodics)
      producer.succeed(with: success)
    }

    return producer
  }

  func testMapPeriodic() {
    let range = 0..<5
    let success = "bye"
    let queue = DispatchQueue(label: "test", qos: DispatchQoS(qosClass: pickQoS(), relativePriority: 0))
    let (periodics, completion) = makeChannel(periodics: range, success: success)
      .mapPeriodic(executor: .queue(queue)) { value -> Int in
        assert(on: queue)
        return value * 2
      }
      .waitForAll()

    XCTAssertEqual(range.map { $0 * 2 }, periodics)
    XCTAssertEqual(success, completion.success)
  }

  func testFilterPeriodic() {
    let range = 0..<5
    let success = "bye"
    let queue = DispatchQueue(label: "test", qos: DispatchQoS(qosClass: pickQoS(), relativePriority: 0))
    let (periodics, completion) = makeChannel(periodics: range, success: success)
      .filterPeriodic(executor: .queue(queue)) { value -> Bool in
        assert(on: queue)
        return 0 == value % 2
      }
      .waitForAll()

    XCTAssertEqual(range.filter { 0 == $0 % 2 }, periodics)
    XCTAssertEqual(success, completion.success)
  }
}
