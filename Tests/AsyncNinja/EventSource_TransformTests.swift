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

class EventSource_TransformTests: XCTestCase {

  static let allTests = [
    ("testDebounce", testDebounce),
    ("testDistinctInts", testDistinctInts),
    ("testDistinctOptionalInts", testDistinctOptionalInts),
    ("testDistinctArrays", testDistinctArrays),
    ("testDistinctNSObjects", testDistinctNSObjects),
    ("testDistinctArrayNSObjects", testDistinctArrayNSObjects),
    ("testSkip", testSkip),
    ("testTake", testTake)
  ]

  func testDebounce() {
    let initalProducer = Producer<Int, String>()
    let derivedProducer = initalProducer.debounce(interval: 0.5)
    let expectation = self.expectation(description: "completion of derived producer")

    derivedProducer.extractAll().onSuccess {
      let (numbers, stringOrError) = $0
      XCTAssertEqual([1, 6, 9, 12], numbers)
      XCTAssertEqual("Finished!", stringOrError.maybeSuccess)
      expectation.fulfill()
    }

    DispatchQueue.global().async {
      mysleep(0.1)
      initalProducer.update(1)
      initalProducer.update(2)
      initalProducer.update(3)
      mysleep(0.25)
      initalProducer.update(4)
      initalProducer.update(5)
      initalProducer.update(6)
      mysleep(0.25)
      initalProducer.update(7)
      initalProducer.update(8)
      initalProducer.update(9)
      mysleep(1.0)
      initalProducer.update(10)
      initalProducer.update(11)
      initalProducer.update(12)
      mysleep(0.2)
      initalProducer.succeed("Finished!")
    }

    self.waitForExpectations(timeout: 5.0)
  }

  func testTrottle() {
    let initalProducer = Producer<Int, String>()
    let derivedProducer = initalProducer.throttle(interval: 0.5) // sendLast as default
    let derivedProducer2 = initalProducer.throttle(interval: 0.5, after: .sendFirst)
    let derivedProducer3 = initalProducer.throttle(interval: 0.5, after: .none)
    let expectation1 = self.expectation(description: "completion of derived producer")
    let expectation2 = self.expectation(description: "completion of derived producer")
    let expectation3 = self.expectation(description: "completion of derived producer")

    derivedProducer.extractAll().onSuccess {
      let (numbers, stringOrError) = $0
      XCTAssertEqual([1, 3, 4, 6], numbers)
      XCTAssertEqual("Finished!", stringOrError.maybeSuccess)
      expectation1.fulfill()
    }

    derivedProducer2.extractAll().onSuccess {
      let (numbers, stringOrError) = $0
      XCTAssertEqual([1, 2, 4, 5], numbers)
      XCTAssertEqual("Finished!", stringOrError.maybeSuccess)
      expectation2.fulfill()
    }

    derivedProducer3.extractAll().onSuccess {
      let (numbers, stringOrError) = $0
      XCTAssertEqual([1, 4], numbers)
      XCTAssertEqual("Finished!", stringOrError.maybeSuccess)
      expectation3.fulfill()
    }

    DispatchQueue.global().async {
      mysleep(0.01)
      initalProducer.update(1)
      mysleep(0.01)
      initalProducer.update(2)
      mysleep(0.01)
      initalProducer.update(3)
      mysleep(1)
      initalProducer.update(4)
      mysleep(0.01)
      initalProducer.update(5)
      mysleep(0.01)
      initalProducer.update(6)
      mysleep(0.01)
      initalProducer.succeed("Finished!")
    }

    self.waitForExpectations(timeout: 2.0)
  }

  func testDistinctInts() {
    let updatable = Producer<Int, String>()
    let expectation = self.expectation(description: "completion of producer")

    updatable.distinct().extractAll().onSuccess {
      let (updates, completion) = $0
      XCTAssertEqual(updates, [1, 2, 3, 4, 5, 6, 7])
      XCTAssertEqual(completion.maybeSuccess, "done")
      expectation.fulfill()
    }

    let fixture = [1, 2, 2, 3, 3, 3, 4, 5, 6, 6, 7]
    DispatchQueue.global().async {
      updatable.update(fixture)
      updatable.succeed("done")
    }

    self.waitForExpectations(timeout: 1.0)
  }

  func testDistinctOptionalInts() {
    let updatable = Producer<Int?, String>()
    let expectation = self.expectation(description: "completion of producer")

    updatable.distinct().extractAll().onSuccess {
      let (updates, completion) = $0
      let assumedResults: [Int?] = [nil, 1, nil, 2, 3, nil, 3, 4, 5, 6, 7]
      XCTAssertEqual(updates.count, assumedResults.count)
      for (update, result) in zip(updates, assumedResults) {
        XCTAssertEqual(update, result)
      }
      XCTAssertEqual(completion.maybeSuccess, "done")
      expectation.fulfill()
    }

    let fixture: [Int?] = [nil, 1, nil, nil, 2, 2, 3, nil, 3, 3, 4, 5, 6, 6, 7]
    DispatchQueue.global().async {
      updatable.update(fixture)
      updatable.succeed("done")
    }

    self.waitForExpectations(timeout: 1.0)
  }

  func testDistinctArrays() {
    let updatable = Producer<[Int], String>()
    let expectation = self.expectation(description: "completion of producer")

    updatable.distinct().extractAll().onSuccess {
      let (updates, completion) = $0
      let assumedResults: [[Int]] = [[1], [1, 2], [1, 2, 3], [1]]
      XCTAssertEqual(updates.count, assumedResults.count)
      for (update, result) in zip(updates, assumedResults) {
        XCTAssert(update == result)
      }
      XCTAssertEqual(completion.maybeSuccess, "done")
      expectation.fulfill()
    }

    let fixture: [[Int]] =  [[1], [1], [1, 2], [1, 2, 3], [1, 2, 3], [1]]
    DispatchQueue.global().async {
      updatable.update(fixture)
      updatable.succeed("done")
    }

    self.waitForExpectations(timeout: 1.0)
  }

  func testDistinctNSObjects() {
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
      let updatable = Producer<NSString, String>()
      let expectation = self.expectation(description: "completion of producer")

      updatable.distinctNSObjects().extractAll().onSuccess {
        let (updates, completion) = $0
        let assumedResults: [NSString] = ["objectA", "objectB", "objectC", "objectA"]
        XCTAssertEqual(updates.count, assumedResults.count)
        for (update, result) in zip(updates, assumedResults) {
          XCTAssert(update == result)
        }
        XCTAssertEqual(completion.maybeSuccess, "done")
        expectation.fulfill()
      }

      let fixture: [NSString] =  ["objectA", "objectA", "objectB", "objectC", "objectC", "objectA"]
      DispatchQueue.global().async {
        updatable.update(fixture)
        updatable.succeed("done")
      }

      self.waitForExpectations(timeout: 1.0)
    #endif
  }

  func testDistinctArrayNSObjects() {
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
      let updatable = Producer<[NSString], String>()
      let expectation = self.expectation(description: "completion of producer")

      let objectA: NSString = "objectA"
      let objectB: NSString = "objectB"
      let objectC: NSString = "objectC"

      updatable.distinctCollectionOfNSObjects().extractAll().onSuccess {
        let (updates, completion) = $0
        let assumedResults: [[NSString]] = [[objectA], [objectA, objectB], [objectA, objectB, objectC], [objectA]]
        XCTAssertEqual(updates.count, assumedResults.count)
        for (update, result) in zip(updates, assumedResults) {
          XCTAssert(update == result)
        }
        XCTAssertEqual(completion.maybeSuccess, "done")
        expectation.fulfill()
      }

      let fixture: [[NSString]] =  [
        [objectA],
        [objectA],
        [objectA, objectB],
        [objectA, objectB, objectC],
        [objectA, objectB, objectC],
        [objectA]
      ]
      DispatchQueue.global().async {
        updatable.update(fixture)
        updatable.succeed("done")
      }

      self.waitForExpectations(timeout: 1.0)
    #endif
  }

  func testSkip() {
    multiTest {
      let source = Producer<Int, String>()
      let sema = DispatchSemaphore(value: 0)
      source.skip(first: 2, last: 3).extractAll()
        .onSuccess {
          let (updates, completion) = $0

          XCTAssertEqual([2, 3, 4, 5, 6], updates)
          XCTAssertEqual("Done", completion.maybeSuccess)
          sema.signal()
      }

      source.update(0..<10)
      source.succeed("Done")
      sema.wait()
    }
  }

  func testTake() {
    multiTest {
      let source = Producer<Int, String>()
      let sema = DispatchSemaphore(value: 0)
      source.take(first: 2, last: 3).extractAll()
        .onSuccess {
          let (updates, completion) = $0

          XCTAssertEqual([0, 1, 7, 8, 9], updates)
          XCTAssertEqual("Done", completion.maybeSuccess)
          sema.signal()
      }

      source.update(0..<10)
      source.succeed("Done")
      sema.wait()
    }

    let result = (channel(updates: [1, 2, 3, 4], success: "Success") as Channel<Int, String>)
      .take(2, completion: "bla", cancellationToken: nil, bufferSize: .specific(2))
      .waitForAll()

    XCTAssert(result.updates == [1, 2])
    XCTAssert(result.completion.maybeSuccess == "bla")
  }
}
