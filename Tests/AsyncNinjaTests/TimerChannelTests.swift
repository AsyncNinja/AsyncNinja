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

class TimerChannelTests: XCTestCase {

  static let allTests = [
    ("testLifetime", testLifetime)
    ]

  func testLifetime() {
    let interval = 0.2
    let initialTime = DispatchTime.now()

    weak var weakTimer: Channel<DispatchTime, Void>? = nil
    weak var weakMappedTimer: Channel<DispatchTime, Void>? = nil
    weak var weakTimesBuffer: Channel<[DispatchTime], Void>? = nil

    let times: [DispatchTime] = eval {
      let timer = makeTimer(interval: interval, DispatchTime.now)
      weakTimer = timer
      XCTAssertNotNil(weakTimer)

      let mappedTimer = timer.map { $0 }
      weakMappedTimer = mappedTimer
      XCTAssertNotNil(weakMappedTimer)

      let timesBuffer = mappedTimer.buffered(capacity: 5)
      weakTimesBuffer = timesBuffer
      XCTAssertNotNil(weakTimesBuffer)

      var iterator = timesBuffer.makeIterator()
      return iterator.next()!
    }

    sleep(1) // lets
    XCTAssertEqual(5, times.count)
    XCTAssertNil(weakTimer)
    XCTAssertNil(weakMappedTimer)
    XCTAssertNil(weakTimesBuffer)

    for (index, time) in times.enumerated() {
      let minTime = initialTime + Double(index + 0) * interval
      XCTAssertLessThanOrEqual(minTime, time)

      let maxTime = initialTime + Double(index + 3) * interval
      XCTAssertLessThanOrEqual(time, maxTime)
    }
  }
}
