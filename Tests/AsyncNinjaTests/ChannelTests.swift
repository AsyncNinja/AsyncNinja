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

class ChannelTests : XCTestCase {
  
  static let allTests = [
    ("testConstant", testConstant),
    ("testIterators", testIterators),
    ("testMap", testMap),
]
  
  func testConstant() {
    let numberOfPeriodics = 5
    let periodics = (0..<numberOfPeriodics).map { _ in pickInt() }
    let success = "final value"
    
    let channelA = channel(periodics: periodics, success: success)
    var periodicsIterator = periodics.makeIterator()
    var channelIterator = channelA.makeIterator()

    while true {
      guard let channelValue = channelIterator.next(), let periodicValue = periodicsIterator.next()
        else { break }

      XCTAssertEqual(channelValue, periodicValue)
    }

    XCTAssertEqual(channelA.finalValue!.success!, success)
  }

  func testIterators() {
    let producer = Producer<Int, String>(bufferSize: 5)
    var iteratorA = producer.makeIterator()
    producer.send(0..<10)
    producer.succeed(with: "finished")
    var iteratorB = producer.makeIterator()

    for index in 0..<10 {
      XCTAssertEqual(iteratorA.next(), index)
    }
    XCTAssertEqual(iteratorA.finalValue?.success, "finished")

    for index in 5..<10 {
      XCTAssertEqual(iteratorB.next(), index)
    }
    XCTAssertEqual(iteratorB.finalValue?.success, "finished")
  }

  func testMap() {
    let producer = Producer<Int, String>()
    let range = 0..<5

    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
      producer.send(range)
      producer.succeed(with: "bye")
    }

    let (periodics, finalValue) = producer
      .mapPeriodic { $0 * 2 }
      .waitForAll()

    XCTAssertEqual(range.map { $0 * 2 }, periodics)
    XCTAssertEqual("bye", finalValue.success)
  }

}
