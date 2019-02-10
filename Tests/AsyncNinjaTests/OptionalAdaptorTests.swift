//
//  Copyright (c) 2017 Anton Mironov
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

class OptionalAdaptorTests: XCTestCase {
  static let allTests = [
    ("testChannelUnsafelyUnrapped", testChannelUnsafelyUnrapped),
    ("testChannelUnrapped", testChannelUnrapped),
    ("testFutureUnsafelyUnrapped", testFutureUnsafelyUnrapped),
    ("testFutureUnrappedKeep", testFutureUnrappedKeep),
    ("testFutureUnrappedReplace", testFutureUnrappedReplace)
    ]

  // MARK: - Channel

  func testChannelUnsafelyUnrapped() {
    let sema = DispatchSemaphore(value: 0)
    let producer = Producer<Int?, String>()
    let unrapped: Channel<Int, String> = producer.unsafelyUnwrapped
    unrapped.extractAll()
      .onSuccess {
        let (updates, completion) = $0
        XCTAssertEqual(updates, [1, 2, 3, 4, 5])
        XCTAssertEqual(completion.maybeSuccess, "done")
        sema.signal()
    }

    producer.update(1)
    producer.update(2)
    producer.update(3)
    producer.update(4)
    producer.update(5)
    producer.succeed("done")
    sema.wait()
  }

  func testChannelUnrapped() {
    let sema = DispatchSemaphore(value: 0)
    let producer = Producer<Int?, String>()
    let unrapped: Channel<Int, String> = producer.unwrapped(0)
    unrapped.extractAll()
      .onSuccess {
        let (updates, completion) = $0
        XCTAssertEqual(updates, [1, 0, 3, 0, 5])
        XCTAssertEqual(completion.maybeSuccess, "done")
        sema.signal()
    }

    producer.update(1)
    producer.update(nil)
    producer.update(3)
    producer.update(nil)
    producer.update(5)
    producer.succeed("done")
    sema.wait()
  }

  // MARK: - Future

  func testFutureUnsafelyUnrapped() {
    let sema = DispatchSemaphore(value: 0)
    let a: Future<Int?> = future(after: 0.1) { 3 }
    let b: Future<Int> = a.unsafelyUnwrapped
    b.onSuccess {
      XCTAssertEqual($0, 3)
      sema.signal()
    }
    sema.wait()
  }

  func testFutureUnrappedKeep() {
    let sema = DispatchSemaphore(value: 0)
    let a: Future<Int?> = future(after: 0.1) { 3 }
    let b: Future<Int> = a.unwrapped(0)
    b.onSuccess {
      XCTAssertEqual($0, 3)
      sema.signal()
    }
    sema.wait()
  }

  func testFutureUnrappedReplace() {
    let sema = DispatchSemaphore(value: 0)
    let a: Future<Int?> = future(after: 0.1) { nil }
    let b: Future<Int> = a.unwrapped(0)
    b.onSuccess {
      XCTAssertEqual($0, 0)
      sema.signal()
    }
    sema.wait()
  }
}
