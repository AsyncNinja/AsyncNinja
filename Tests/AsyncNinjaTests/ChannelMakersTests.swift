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

class ChannelMakersTests: XCTestCase {

  static let allTests = [
    ("testMakeChannel", testMakeChannel),
    ("testMakeChannelContextual", testMakeChannelContextual),
    ("testCompletedWithFunc", testCompletedWithFunc),
    ("testCompletedWithStatic", testCompletedWithStatic),
    ("testSucceededWithFunc", testSucceededWithFunc),
    ("testSucceededWithStatic", testSucceededWithStatic),
    ("testSucceededWithJust", testSucceededWithJust),
    ("testFailedWithFunc", testFailedWithFunc),
    ("testFailedWithStatic", testFailedWithStatic),
    ("testCancelled", testCancelled)
    ]

  func testMakeChannel() {
    let numbers = Array(0..<100)

    let channelA: Channel<Int, String> = channel { (updateUpdate) -> String in
      for i in numbers {
        updateUpdate(i)
      }
      return "done"
    }

    var resultNumbers = [Int]()
    let serialQueue = DispatchQueue(label: "test-queue")
    let expectation = self.expectation(description: "channel to complete")

    channelA.onUpdate(executor: .queue(serialQueue)) {
      resultNumbers.append($0)
    }

    channelA.onSuccess(executor: .queue(serialQueue)) {
      XCTAssertEqual("done", $0)
      expectation.fulfill()
    }

    self.waitForExpectations(timeout: 1.0, handler: nil)

    XCTAssertEqual(resultNumbers, Array(numbers.suffix(resultNumbers.count)))
  }

  func testMakeChannelContextual() {
    multiTest(repeating: 100) {
      let numbers = Array(0..<10)
      let actor = TestActor()
      let supportingSema = DispatchSemaphore(value: 0)
      let sema = DispatchSemaphore(value: 0)
      actor.async { _ in
        supportingSema.wait()
      }

      let channelA: Channel<Int, String> = channel(context: actor) { (_, updateUpdate) -> String in
        for i in numbers {
          updateUpdate(i)
        }
        return "done"
      }

      var resultNumbers = [Int]()
      let serialQueue = DispatchQueue(label: "test-queue")

      channelA.onUpdate(executor: .queue(serialQueue)) {
        resultNumbers.append($0)
      }

      channelA.onSuccess(executor: .queue(serialQueue)) {
        XCTAssertEqual("done", $0)
        sema.signal()
      }

      supportingSema.signal()
      sema.wait()
      XCTAssertEqual(resultNumbers, Array(numbers.suffix(resultNumbers.count)))
    }
  }

  func testCompletedWithFunc() {
    let channel_ = channel(updates: 1...5, completion: .success("success"))
    let (updates, completion) = channel_.waitForAll()
    XCTAssertEqual([1, 2, 3, 4, 5], updates)
    if case let .success(value) = completion {
      XCTAssertEqual(value, "success")
    } else {
      XCTFail()
    }
  }

  func testCompletedWithStatic() {
    let channel_ = Channel<Int, String>.completed(.success("success"))
    let (updates, completion) = channel_.waitForAll()
    XCTAssertEqual([], updates)
    if case let .success(value) = completion {
      XCTAssertEqual(value, "success")
    } else {
      XCTFail()
    }
  }

  func testSucceededWithFunc() {
    let channel_ = channel(updates: 1...5, success: "success")
    let (updates, completion) = channel_.waitForAll()
    XCTAssertEqual([1, 2, 3, 4, 5], updates)
    if case let .success(value) = completion {
      XCTAssertEqual(value, "success")
    } else {
      XCTFail()
    }
  }

  func testSucceededWithStatic() {
    let channel_ = Channel<Int, String>.succeeded("success")
    let (updates, completion) = channel_.waitForAll()
    XCTAssertEqual([], updates)
    if case let .success(value) = completion {
      XCTAssertEqual(value, "success")
    } else {
      XCTFail()
    }
  }

  func testSucceededWithJust() {
    let channel_ = Channel<Int, String>.just("success")
    let (updates, completion) = channel_.waitForAll()
    XCTAssertEqual([], updates)
    if case let .success(value) = completion {
      XCTAssertEqual(value, "success")
    } else {
      XCTFail()
    }
  }

  func testFailedWithFunc() {
    let channel_: Channel<Int, String> = channel(updates: 1...5, failure: TestError.testCode)
    let (updates, completion) = channel_.waitForAll()
    XCTAssertEqual([1, 2, 3, 4, 5], updates)
    if case let .failure(error) = completion,
      let testError = error as? TestError,
      case .testCode = testError {
      nop()
    } else {
      XCTFail()
    }
  }

  func testFailedWithStatic() {
    let channel_ = Channel<Int, String>.failed(TestError.testCode)
    let (updates, completion) = channel_.waitForAll()
    XCTAssertEqual([], updates)
    if case let .failure(error) = completion,
      let testError = error as? TestError,
      case .testCode = testError {
      nop()
    } else {
      XCTFail()
    }
  }

  func testCancelled() {
    let channel_ = Channel<Int, String>.cancelled
    let (updates, completion) = channel_.waitForAll()
    XCTAssertEqual([], updates)
    if case let .failure(error) = completion,
      let testError = error as? AsyncNinjaError,
      case .cancelled = testError {
      nop()
    } else {
      XCTFail()
    }
  }
}
