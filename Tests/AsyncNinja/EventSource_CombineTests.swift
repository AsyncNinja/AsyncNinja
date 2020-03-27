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
    ("testSuspendable", testSuspendable)
  ]

  func testSample() {
    let producerOfOdds = Producer<Int, String>()
    let producerOfEvents = Producer<Int, String>()
    let channelOfNumbers = producerOfOdds.sample(with: producerOfEvents)
    let expectation = self.expectation(description: "async checks to finish")

    channelOfNumbers.extractAll()
      .onSuccess {
      let (pairs, stringsOfError) = $0
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

      XCTAssertEqual(stringsOfError.maybeSuccess!.0, "Hello")
      XCTAssertEqual(stringsOfError.maybeSuccess!.1, "World")
      expectation.fulfill()
    }

    DispatchQueue.global().async {
      mysleep(0.1)
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

  func testSuspendable() {
    let source = Producer<Int, String>()
    let controller = Producer<Bool, String>()
    let sema = DispatchSemaphore(value: 0)
    source.suspendable(controller, suspensionBufferSize: 2).extractAll()
      .onSuccess {
        let (updates, completion) = $0
        XCTAssertEqual([4, 5, 6, 7, 8, 9, 10, 11, 13, 14], updates)
        XCTAssertEqual("Done", completion.maybeSuccess!)
        sema.signal()
    }

    source.update(0..<3)
    controller.update(false)
    source.update(3..<6)
    controller.update(true)
    source.update(6..<9)
    controller.update(true)
    source.update(9..<12)
    controller.update(false)
    source.update(12..<15)
    controller.update(true)
    source.succeed("Done")
    sema.wait()
  }

  func testCombineCompletion() {
    let exp = expectation(description: "combine")

    let actor = TestActor()

    let promise1 = Promise<String>()
    let promise2 = Promise<String>()

    let expectation = ("completion1", "completion2")

    actor.combine(promise1, promise2)
      .onSuccess { success in XCTAssert(success == expectation); exp.fulfill() }

    promise1.succeed("completion1")
    promise2.succeed("completion2")

    waitForExpectations(timeout: 1, handler: nil)
  }

  func testCombineLatest2() {
    let actor = TestActor()

    let source1 = Producer<String, String>()
    let source2 = Producer<String, String>()

    var expectations = [["src1_upd2", "src2_upd2"],
                        ["src1_upd2", "src2_upd1"],
                        ["src1_upd1", "src2_upd1"]]  // last is first

    actor.combineLatest(source1, source2, executor: Executor.immediate)
      .onUpdate { upd in
        guard let last = expectations.popLast() else { return }
        XCTAssertEqual(last, [upd.0, upd.1])
      }
      .onSuccess { success in
        XCTAssertEqual([success.0, success.1], ["success1", "success2"])
      }

    source1.update("src1_upd1", from: Executor.immediate)
    source2.update("src2_upd1", from: Executor.immediate)

    source1.update("src1_upd2", from: Executor.immediate)

    source2.update("src2_upd2", from: Executor.immediate)

    source1.succeed("success1", from: Executor.immediate)
    source2.succeed("success2", from: Executor.immediate)

    XCTAssert(expectations.count == 0)
  }

  func testCombineLatest3() {
    let actor = TestActor()

    let source1 = Producer<Int, Int>()
    let source2 = Producer<Int, Int>()
    let source3 = Producer<Int, Int>()

    var expectations = [[1, 2, 2],
                        [1, 1, 2],
                        [1, 1, 1]]  // last is first

    actor.combineLatest(source1, source2, source3, executor: Executor.immediate)
      .onUpdate { upd in
        guard let last = expectations.popLast() else { return }
        XCTAssertEqual(last, [upd.0, upd.1, upd.2])
      }
      .onSuccess { success in
        XCTAssertEqual([success.0, success.1, success.2], [1, 2, 3])
    }

    source1.update(1, from: Executor.immediate)
    source2.update(1, from: Executor.immediate)
    source3.update(1, from: Executor.immediate)

    source3.update(2, from: Executor.immediate)

    source2.update(2, from: Executor.immediate)

    source1.succeed(1, from: Executor.immediate)
    source2.succeed(2, from: Executor.immediate)
    source3.succeed(3, from: Executor.immediate)

    XCTAssert(expectations.count == 0)
  }

  func testCombineLatest4() {
    let actor = TestActor()

    let source1 = Producer<Int, Int>()
    let source2 = Producer<Int, Int>()
    let source3 = Producer<Int, Int>()
    let source4 = Producer<Int, Int>()

    var expectations = [[1, 1, 2, 2],
                        [1, 1, 1, 2],
                        [1, 1, 1, 1]]  // last is first

    actor.combineLatest(source1, source2, source3, source4, executor: Executor.immediate)
      .onUpdate { upd in
        guard let last = expectations.popLast() else { return }
        XCTAssertEqual(last, [upd.0, upd.1, upd.2, upd.3])
      }
      .onSuccess { success in
        XCTAssertEqual([success.0, success.1, success.2, success.3], [1, 2, 3, 4])
    }

    source1.update(1, from: Executor.immediate)
    source2.update(1, from: Executor.immediate)
    source3.update(1, from: Executor.immediate)
    source4.update(1, from: Executor.immediate)

    source4.update(2, from: Executor.immediate)

    source3.update(2, from: Executor.immediate)

    source1.succeed(1, from: Executor.immediate)
    source2.succeed(2, from: Executor.immediate)
    source3.succeed(3, from: Executor.immediate)
    source3.succeed(4, from: Executor.immediate)

    XCTAssert(expectations.count == 0)
  }

  func testStartWith() {
    let exp = expectation(description: "")
    var expResult = [6, 6, 7, 2, 3, 4]
    channel(updates: [2, 3, 4], success: ())
      .startWith([6, 6, 7])
      .onUpdate(executor: Executor.default) { XCTAssertEqual($0, expResult.first!); expResult.removeFirst() }
      .onSuccess { _ in
        exp.fulfill()
    }

    waitForExpectations(timeout: 10, handler: nil)
  }

  func testWithLatest() {
    let exp = expectation(description: "")

    let eventProducer = Producer<Int, Void>()
    let optionProducer = Producer<String, Void>()

    eventProducer
      .withLatest(from: optionProducer)
      .onUpdate { print("update \($0)") }
      .onSuccess { exp.fulfill() }

    eventProducer.update(-1)
    eventProducer.update(0)
    optionProducer.update("is on")
    eventProducer.update(0)
    optionProducer.update("skip me")
    optionProducer.update("skip me")
    optionProducer.update("is off")
    eventProducer.update(1)
    eventProducer.update(2)
    optionProducer.update("is off")
    eventProducer.update(3)
    eventProducer.succeed()

    waitForExpectations(timeout: 2, handler: nil)
  }

  func testSwitchIfEmpty() {
    do {
      let switchTo = [4, 5, 6].valuesChannel(after: 0.1, interval: 0.1)
      let ifNotEmpty = [1, 2, 3].valuesChannel(after: 0.1, interval: 0.1)
        .ifEmpty(switchTo: switchTo)
        .waitForAll()

      XCTAssertEqual(ifNotEmpty.updates, [1, 2, 3])
    }

    do {
      let switchTo = [4, 5, 6].valuesChannel(after: 0.1, interval: 0.1)
      let ifEmpty = [Int]().valuesChannel(after: 0.1, interval: 0.1)
        .ifEmpty(switchTo: switchTo)
        .waitForAll()

      XCTAssertEqual(ifEmpty.updates, [4, 5, 6])
    }
  }

  func testSwitchIfEmptyBuffered() {
    do {
      let switchTo = channel(updates: [4, 5, 6], success: ())
      let ifNotEmpty = channel(updates: [1, 2, 3], success: ())
        .ifEmpty(switchTo: switchTo)
        .waitForAll()

      XCTAssertEqual(ifNotEmpty.updates, [1, 2, 3])
    }

    do {
      let switchTo = channel(updates: [4, 5, 6], success: ())
      let ifEmpty = channel(updates: [], success: ())
        .ifEmpty(switchTo: switchTo)
        .waitForAll()

      XCTAssertEqual(ifEmpty.updates, [4, 5, 6])
    }
  }
}
