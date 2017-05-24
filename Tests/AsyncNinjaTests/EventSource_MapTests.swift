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

class EventSource_MapTests: XCTestCase {

  static let allTests = [
    ("testMapEvent", testMapEvent),
    ("testMapEventContextual", testMapEventContextual),
    ("testMap", testMap),
    ("testMapContextual", testMapContextual),
    ("testFilter", testFilter),
    ("testFilterContextual", testFilterContextual),
    ("testFlatMapArray", testFlatMapArray),
    ("testFlatMapArrayContextual", testFlatMapArrayContextual),
    ("testFlatMapOptional", testFlatMapOptional),
    ("testFlatMapOptionalContextual", testFlatMapOptionalContextual)
  ]

  func makeChannel<S: Sequence, T>(updates: S, success: T) -> Channel<S.Iterator.Element, T> {
    let producer = Producer<S.Iterator.Element, T>()

    DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
      producer.update(updates)
      producer.succeed(success)
    }

    return producer
  }

  func testMapEvent() {
    let range = 0..<5
    let success = "bye"
    let queue = DispatchQueue(label: "test", qos: DispatchQoS(qosClass: pickQoS(), relativePriority: 0))
    let (updates, completion) = makeChannel(updates: range, success: success)
      .mapEvent(executor: .queue(queue)) { value -> ChannelEvent<Int, String> in
        assert(on: queue)
        switch value {
        case let .update(value):
          return .update(value * 2)
        case let .completion(.success(value)):
          return .success(value + "!")
        case let .completion(.failure(value)):
          throw value
        }
      }
      .waitForAll()

    XCTAssertEqual(range.map { $0 * 2 }, updates)
    XCTAssertEqual(success + "!", completion.success)
  }

  func testMapEventContextual() {
    let range = 0..<5
    let success = "bye"
    let actor = TestActor()
    let (updates, completion) = makeChannel(updates: range, success: success)
      .mapEvent(context: actor) { (actor_, value) -> ChannelEvent<Int, String> in
        assert(actor === actor_)
        assert(on: actor_.internalQueue)
        switch value {
        case let .update(value):
          return .update(value * 2)
        case let .completion(.success(value)):
          return .success(value + "!")
        case let .completion(.failure(value)):
          throw value
        }
      }
      .waitForAll()

    XCTAssertEqual(range.map { $0 * 2 }, updates)
    XCTAssertEqual(success + "!", completion.success)
  }

  func testMap() {
    let range = 0..<5
    let success = "bye"
    let queue = DispatchQueue(label: "test", qos: DispatchQoS(qosClass: pickQoS(), relativePriority: 0))
    let (updates, completion) = makeChannel(updates: range, success: success)
      .map(executor: .queue(queue)) { value -> Int in
        assert(on: queue)
        return value * 2
      }
      .waitForAll()

    XCTAssertEqual(range.map { $0 * 2 }, updates)
    XCTAssertEqual(success, completion.success)
  }

  func testMapContextual() {
    let range = 0..<5
    let success = "bye"
    let actor = TestActor()
    let (updates, completion) = makeChannel(updates: range, success: success)
      .map(context: actor) { (actor_, value) -> Int in
        assert(actor_ === actor)
        assert(on: actor_.internalQueue)
        return value * 2
      }
      .waitForAll()

    XCTAssertEqual(range.map { $0 * 2 }, updates)
    XCTAssertEqual(success, completion.success)
  }

  func testFilter() {
    let range = 0..<5
    let success = "bye"
    let queue = DispatchQueue(label: "test", qos: DispatchQoS(qosClass: pickQoS(), relativePriority: 0))
    let (updates, completion) = makeChannel(updates: range, success: success)
      .filter(executor: .queue(queue)) { value -> Bool in
        assert(on: queue)
        return 0 == value % 2
      }
      .waitForAll()

    XCTAssertEqual(range.filter { 0 == $0 % 2 }, updates)
    XCTAssertEqual(success, completion.success)
  }

  func testFilterContextual() {
    let range = 0..<5
    let success = "bye"
    let actor = TestActor()
    let (updates, completion) = makeChannel(updates: range, success: success)
      .filter(context: actor) { (actor_, value) -> Bool in
        assert(actor_ === actor)
        assert(on: actor_.internalQueue)
        return 0 == value % 2
      }
      .waitForAll()

    XCTAssertEqual(range.filter { 0 == $0 % 2 }, updates)
    XCTAssertEqual(success, completion.success)
  }

  func testFlatMapArray() {
    let range = 0..<5
    let success = "bye"
    let queue = DispatchQueue(label: "test", qos: DispatchQoS(qosClass: pickQoS(), relativePriority: 0))
    let (updates, completion) = makeChannel(updates: range, success: success)
      .flatMap(executor: .queue(queue)) { value -> [Int] in
        assert(on: queue)
        return Array(repeating: value, count: value)
      }
      .waitForAll()

    XCTAssertEqual([1, 2, 2, 3, 3, 3, 4, 4, 4, 4], updates)
    XCTAssertEqual(success, completion.success)
  }

  func testFlatMapArrayContextual() {
    let range = 0..<5
    let success = "bye"
    let actor = TestActor()
    let (updates, completion) = makeChannel(updates: range, success: success)
      .flatMap(context: actor) { (actor_, value) -> [Int] in
        assert(actor_ === actor)
        assert(on: actor_.internalQueue)
        return Array(repeating: value, count: value)
      }
      .waitForAll()

    XCTAssertEqual([1, 2, 2, 3, 3, 3, 4, 4, 4, 4], updates)
    XCTAssertEqual(success, completion.success)
  }

  func testFlatMapOptional() {
    let range = 0..<5
    let success = "bye"
    let queue = DispatchQueue(label: "test", qos: DispatchQoS(qosClass: pickQoS(), relativePriority: 0))
    let (updates, completion) = makeChannel(updates: range, success: success)
      .flatMap(executor: .queue(queue)) { value -> Int? in
        assert(on: queue)
        return 1 == value % 2 ? nil : value * 2
      }
      .waitForAll()

    XCTAssertEqual([0, 4, 8], updates)
    XCTAssertEqual(success, completion.success)
  }

  func testFlatMapOptionalContextual() {
    let range = 0..<5
    let success = "bye"
    let actor = TestActor()
    let (updates, completion) = makeChannel(updates: range, success: success)
      .flatMap(context: actor) { (actor_, value) -> Int? in
        assert(actor_ === actor)
        assert(on: actor_.internalQueue)
        return 1 == value % 2 ? nil : value * 2
      }
      .waitForAll()

    XCTAssertEqual([0, 4, 8], updates)
    XCTAssertEqual(success, completion.success)
  }
}
