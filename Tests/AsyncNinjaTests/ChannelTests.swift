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

class ChannelTests : XCTestCase {
  
  static let allTests = [
    ("testIterators", testIterators),
    ("testMapPeriodic", testMapPeriodic),
    ("testFilterPeriodic", testFilterPeriodic),
    ("testMakeChannel", testMakeChannel),
    ("testOnValueContextual", testOnValueContextual),
    ("testOnValue", testOnValue),
    ("testBuffering0", testBuffering0),
    ("testBuffering1", testBuffering1),
    ("testBuffering2", testBuffering2),
    ("testBuffering3", testBuffering3),
    ("testBuffering10", testBuffering10),
    ("testFirstSuccessIncomplete", testFirstSuccessIncomplete),
    ("testFirstNotFound", testFirstNotFound),
    ("testFirstFailure", testFirstFailure),
    ("testFirstSuccessIncompleteContextual", testFirstSuccessIncompleteContextual),
    ("testFirstNotFoundContextual", testFirstNotFoundContextual),
    ("testFirstFailureContextual", testFirstFailureContextual),
    ("testFirstDeadContextual", testFirstDeadContextual),
    ("testLastSuccess", testLastSuccess),
    ("testLastNotFound", testLastNotFound),
    ("testLastFailure", testLastFailure),
    ("testLastSuccessContextual", testLastSuccessContextual),
    ("testLastNotFoundContextual", testLastNotFoundContextual),
    ("testLastFailureContextual", testLastFailureContextual),
    ("testLastDeadContextual", testLastDeadContextual),
    ("testMergeInts", testMergeInts),
    ("testMergeIntsAndStrings", testMergeIntsAndStrings),
    ("testZip", testZip),
    ("testSample", testSample),
    ("testDebounce", testDebounce)
  ]

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
    let final = "bye"
    let queue = DispatchQueue(label: "test", qos: DispatchQoS(qosClass: pickQoS(), relativePriority: 0))
    let (periodics, finalValue) = makeChannel(periodics: range, success: final)
      .mapPeriodic(executor: .queue(queue)) { value -> Int in
        assert(on: queue)
        return value * 2
      }
      .waitForAll()

    XCTAssertEqual(range.map { $0 * 2 }, periodics)
    XCTAssertEqual(final, finalValue.success)
  }

  func testFilterPeriodic() {
    let range = 0..<5
    let final = "bye"
    let queue = DispatchQueue(label: "test", qos: DispatchQoS(qosClass: pickQoS(), relativePriority: 0))
    let (periodics, finalValue) = makeChannel(periodics: range, success: final)
      .filterPeriodic(executor: .queue(queue)) { value -> Bool in
        assert(on: queue)
        return 0 == value % 2
      }
      .waitForAll()

    XCTAssertEqual(range.filter { 0 == $0 % 2 }, periodics)
    XCTAssertEqual(final, finalValue.success)
  }

  func testMakeChannel() {
    let numbers = Array(0..<100)

    let channelA: Channel<Int, String> = channel { (sendPeriodic) -> String in
      for i in numbers {
        sendPeriodic(i)
      }
      return "done"
    }

    var resultNumbers = [Int]()
    let serialQueue = DispatchQueue(label: "test-queue")
    let expectation = self.expectation(description: "channel to complete")

    channelA.onPeriodic(executor: .queue(serialQueue)) {
      resultNumbers.append($0)
    }

    channelA.onSuccess(executor: .queue(serialQueue)) {
      XCTAssertEqual("done", $0)
      expectation.fulfill()
    }

    self.waitForExpectations(timeout: 1.0, handler: nil)

    XCTAssertEqual(resultNumbers, Array(numbers.suffix(resultNumbers.count)))
  }

  func testOnValueContextual() {
    let actor = TestActor()

    var periodicValues = [Int]()
    var successValue: String? = nil
    weak var weakProducer: Producer<Int, String>? = nil

    let periodicValuesFixture = pickInts()
    let successValueFixture = "I am working correctly!"

    let successExpectation = self.expectation(description: "success of promise")
    DispatchQueue.global().async {
      let producer = Producer<Int, String>()
      weakProducer = producer
      producer.onPeriodic(context: actor) { (actor, periodicValue) in
        periodicValues.append(periodicValue)
      }

      producer.onSuccess(context: actor) { (actor, successValue_) in
        successValue = successValue_
        successExpectation.fulfill()
      }

      DispatchQueue.global().async {
        guard let producer = weakProducer else {
          XCTFail()
          fatalError()
        }
        producer.send(periodicValuesFixture)
        producer.succeed(with: successValueFixture)
      }
    }

    self.waitForExpectations(timeout: 0.2, handler: nil)

    XCTAssertNil(weakProducer)
    XCTAssertEqual(periodicValues, periodicValuesFixture)
    XCTAssertEqual(successValue, successValueFixture)
  }

  func testOnValue() {
    var periodicValues = [Int]()
    var successValue: String? = nil
    weak var weakProducer: Producer<Int, String>? = nil

    let periodicValuesFixture = pickInts()
    let successValueFixture = "I am working correctly!"

    let successExpectation = self.expectation(description: "success of promise")
    let queue = DispatchQueue(label: "testing queue", qos: DispatchQoS(qosClass: pickQoS(), relativePriority: 0))

    DispatchQueue.global().async {
      let producer = Producer<Int, String>()
      weakProducer = producer
      producer.onPeriodic(executor: .queue(queue)) { (periodicValue) in
        periodicValues.append(periodicValue)
      }

      producer.onSuccess(executor: .queue(queue)) { (successValue_) in
        successValue = successValue_
        successExpectation.fulfill()
      }

      DispatchQueue.global().async {
        guard let producer = weakProducer else {
          XCTFail()
          fatalError()
        }
        producer.send(periodicValuesFixture)
        producer.succeed(with: successValueFixture)
      }
    }

    self.waitForExpectations(timeout: 0.2, handler: nil)

    XCTAssertNil(weakProducer)
    XCTAssertEqual(periodicValues, periodicValuesFixture)
    XCTAssertEqual(successValue, successValueFixture)
  }

  func testBuffering0() {
    _testBuffering(bufferSize: 0)
  }

  func testBuffering1() {
    _testBuffering(bufferSize: 1)
  }

  func testBuffering2() {
    _testBuffering(bufferSize: 2)
  }

  func testBuffering3() {
    _testBuffering(bufferSize: 3)
  }

  func testBuffering10() {
    _testBuffering(bufferSize: 10)
  }

  func _testBuffering(bufferSize: Int, file: StaticString = #file, line: UInt = #line) {
    let fixture = pickInts(count: 100)
    let queue = DispatchQueue(label: "testing queue", qos: DispatchQoS(qosClass: pickQoS(), relativePriority: 0))
    let producer = Producer<Int, Void>(bufferSize: bufferSize)

    producer.send(pickInts())
    producer.send(fixture.prefix(upTo: bufferSize))

    var periodics = [Int]()
    producer.onPeriodic(executor: .queue(queue)) {
      periodics.append($0)
    }
    producer.send(fixture.suffix(from: bufferSize))
    producer.succeed(with: ())

    let expectation = self.expectation(description: "completion of producer")
    producer.onSuccess(executor: .queue(queue)) {
      expectation.fulfill()
    }
    
    self.waitForExpectations(timeout: 1.0, handler: nil)
    
    XCTAssertEqual(periodics, fixture, file: file, line: line)
  }

  func testFirstSuccessIncomplete() {
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")
    let qos = pickQoS()

    producer.first(executor: .queue(qos)) {
      assert(nonGlobalQoS: qos)
      return 0 == $0 % 2
      }
      .onSuccess(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        XCTAssertEqual(8, $0)
        expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    producer.send(5)
    producer.send(7)
    producer.send(8)
    producer.send(9)
    producer.send(10)

    self.waitForExpectations(timeout: 1.0)
  }
  
  func testFirstNotFound() {
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")
    let qos = pickQoS()

    producer.first(executor: .queue(qos)) {
      assert(nonGlobalQoS: qos)
      return 0 == $0 % 2
      }
      .onSuccess(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        XCTAssertNil($0)
        expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    producer.send(5)
    producer.send(7)
    producer.send(9)
    producer.succeed(with: ())

    self.waitForExpectations(timeout: 1.0)
  }

  func testFirstFailure() {
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")
    let qos = pickQoS()

    producer.first(executor: .queue(qos)) {
      assert(nonGlobalQoS: qos)
      return 0 == $0 % 2
      }
      .onFailure(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        XCTAssertEqual($0 as! TestError, TestError.testCode)
        expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    producer.send(5)
    producer.send(7)
    producer.send(9)
    producer.fail(with: TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testFirstSuccessIncompleteContextual() {
    let actor = TestActor()
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")

    producer.first(context: actor) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
      }
      .onSuccess(context: actor) { (actor, value) in
        assert(actor: actor)
        XCTAssertEqual(8, value)
        expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    producer.send(5)
    producer.send(7)
    producer.send(8)
    producer.send(9)
    producer.send(10)

    self.waitForExpectations(timeout: 1.0)
  }


  func testFirstNotFoundContextual() {
    let actor = TestActor()
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")

    producer.first(context: actor) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
      }
      .onSuccess(context: actor) { (actor, value) in
        assert(actor: actor)
        XCTAssertNil(value)
        expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    producer.send(5)
    producer.send(7)
    producer.send(9)
    producer.succeed(with: ())

    self.waitForExpectations(timeout: 1.0)
  }

  func testFirstFailureContextual() {
    let actor = TestActor()
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")

    producer.first(context: actor) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
      }
      .onFailure(context: actor) { (actor, failure) in
        assert(actor: actor)
        XCTAssertEqual(failure as! TestError, TestError.testCode)
        expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    producer.send(5)
    producer.send(7)
    producer.send(9)
    producer.fail(with: TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testFirstDeadContextual() {
    var actor: TestActor? = TestActor()
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")

    let future = producer.first(context: actor!) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
    }
    future.onFailure { (failure) in
      XCTAssertEqual(failure as! AsyncNinjaError, AsyncNinjaError.contextDeallocated)
      expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    actor = nil
    producer.send(5)
    producer.send(8)
    producer.send(7)
    producer.send(9)
    producer.fail(with: TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastSuccess() {
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")
    let qos = pickQoS()

    producer.last(executor: .queue(qos)) {
      assert(nonGlobalQoS: qos)
      return 0 == $0 % 2
      }
      .onSuccess(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        XCTAssertEqual(10, $0)
        expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    producer.send(5)
    producer.send(7)
    producer.send(8)
    producer.send(9)
    producer.send(10)
    producer.succeed(with: ())

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastNotFound() {
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")
    let qos = pickQoS()

    producer.last(executor: .queue(qos)) {
      assert(nonGlobalQoS: qos)
      return 0 == $0 % 2
      }
      .onSuccess(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        XCTAssertNil($0)
        expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    producer.send(5)
    producer.send(7)
    producer.send(9)
    producer.succeed(with: ())

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastFailure() {
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")
    let qos = pickQoS()

    producer.last(executor: .queue(qos)) {
      assert(nonGlobalQoS: qos)
      return 0 == $0 % 2
      }
      .onFailure(executor: .queue(qos)) {
        assert(nonGlobalQoS: qos)
        XCTAssertEqual($0 as! TestError, TestError.testCode)
        expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    producer.send(5)
    producer.send(7)
    producer.send(9)
    producer.fail(with: TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastSuccessContextual() {
    let actor = TestActor()
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")

    producer.last(context: actor) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
      }
      .onSuccess(context: actor) { (actor, value) in
        assert(actor: actor)
        XCTAssertEqual(10, value)
        expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    producer.send(5)
    producer.send(7)
    producer.send(8)
    producer.send(9)
    producer.send(10)
    producer.succeed(with: ())

    self.waitForExpectations(timeout: 1.0)
  }


  func testLastNotFoundContextual() {
    let actor = TestActor()
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")

    producer.last(context: actor) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
      }
      .onSuccess(context: actor) { (actor, value) in
        assert(actor: actor)
        XCTAssertNil(value)
        expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    producer.send(5)
    producer.send(7)
    producer.send(9)
    producer.succeed(with: ())

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastFailureContextual() {
    let actor = TestActor()
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")

    producer.last(context: actor) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
      }
      .onFailure(context: actor) { (actor, failure) in
        assert(actor: actor)
        XCTAssertEqual(failure as! TestError, TestError.testCode)
        expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    producer.send(5)
    producer.send(7)
    producer.send(9)
    producer.fail(with: TestError.testCode)

    self.waitForExpectations(timeout: 1.0)
  }

  func testLastDeadContextual() {
    var actor: TestActor? = TestActor()
    let producer = Producer<Int, Void>()
    let expectation = self.expectation(description: "future to finish")

    let future = producer.last(context: actor!) { (actor, value) in
      assert(actor: actor)
      return 0 == value % 2
    }
    future.onFailure { (failure) in
      XCTAssertEqual(failure as! AsyncNinjaError, AsyncNinjaError.contextDeallocated)
      expectation.fulfill()
    }

    producer.send(1)
    producer.send(3)
    actor = nil
    producer.send(5)
    producer.send(8)
    producer.send(7)
    producer.send(9)
    producer.fail(with: TestError.testCode)
    
    self.waitForExpectations(timeout: 1.0)
  }

  func testMergeInts() {
    let producerOfOdds = Producer<Int, String>()
    let producerOfEvents = Producer<Int, String>()
    let channelOfNumbers = merge(producerOfOdds, producerOfEvents)

    DispatchQueue.global().async {
      producerOfOdds.send(1)
      producerOfOdds.send(3)
      producerOfEvents.send(2)
      producerOfEvents.send(4)
      producerOfOdds.send(5)
      producerOfEvents.send(6)
      producerOfOdds.send(7)
      producerOfOdds.succeed(with: "Hello")
      producerOfEvents.send(8)
      producerOfEvents.succeed(with: "World")
    }

    let (numbers, stringsOfError) = channelOfNumbers.waitForAll()

    XCTAssertEqual(numbers, [1, 3, 2, 4, 5, 6, 7, 8])
    XCTAssertEqual(stringsOfError.success!.0, "Hello")
    XCTAssertEqual(stringsOfError.success!.1, "World")
  }

  func testMergeIntsAndStrings() {
    let producerOfOdds = Producer<Int, String>()
    let producerOfEvents = Producer<String, String>()
    let channelOfNumbers = merge(producerOfOdds, producerOfEvents)

    DispatchQueue.global().async {
      producerOfOdds.send(1)
      producerOfOdds.send(3)
      producerOfEvents.send("two")
      producerOfEvents.send("four")
      producerOfOdds.send(5)
      producerOfEvents.send("six")
      producerOfOdds.send(7)
      producerOfOdds.succeed(with: "Hello")
      producerOfEvents.send("eight")
      producerOfEvents.succeed(with: "World")
    }

    let (numbers, stringsOfError) = channelOfNumbers.waitForAll()

    let fixtureNumbers: [Either<Int, String>] = [.left(1), .left(3), .right("two"), .right("four"), .left(5), .right("six"), .left(7), .right("eight")]
    XCTAssertEqual(numbers.count, fixtureNumbers.count)
    for (number, fixture) in zip(numbers, fixtureNumbers) {
      XCTAssert(number == fixture)
    }
    XCTAssertEqual(stringsOfError.success!.0, "Hello")
    XCTAssertEqual(stringsOfError.success!.1, "World")
  }

  func testZip() {
    let producerOfOdds = Producer<Int, String>()
    let producerOfEvents = Producer<Int, String>()
    let expectation = self.expectation(description: "channel to finish")

    zip(producerOfOdds, producerOfEvents)
      .extractAll { (pairs, stringsOfError) in
        let fixturePairs = [(1, 2), (3, 4), (5, 6), (7, 8)]
        XCTAssertEqual(fixturePairs.count, pairs.count)
        for (pair, fixturePair) in zip(pairs, fixturePairs) {
          XCTAssertEqual(pair.0, fixturePair.0)
          XCTAssertEqual(pair.1, fixturePair.1)
        }

        XCTAssertEqual(stringsOfError.success!.0, "Hello")
        XCTAssertEqual(stringsOfError.success!.1, "World")
        expectation.fulfill()
    }

    DispatchQueue.global().async {
      producerOfOdds.send(1)
      producerOfOdds.send(3)
      producerOfEvents.send(2)
      producerOfEvents.send(4)
      producerOfOdds.send(5)
      producerOfEvents.send(6)
      producerOfOdds.send(7)
      producerOfOdds.succeed(with: "Hello")
      producerOfEvents.send(8)
      producerOfEvents.send(10)
      producerOfEvents.succeed(with: "World")
    }

    self.waitForExpectations(timeout: 1.0)
  }

  func testSample() {
    let producerOfOdds = Producer<Int, String>()
    let producerOfEvents = Producer<Int, String>()
    let channelOfNumbers = producerOfOdds.sample(with: producerOfEvents)
    let expectation = self.expectation(description: "async checks to finish")

    channelOfNumbers.extractAll { (pairs, stringsOfError) in
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
      producerOfOdds.send(1)
      producerOfOdds.send(3)
      producerOfEvents.send(2)
      producerOfEvents.send(4)
      producerOfOdds.send(5)
      producerOfEvents.send(6)
      producerOfOdds.send(7)
      producerOfOdds.succeed(with: "Hello")
      producerOfEvents.send(8)
      producerOfEvents.succeed(with: "World")
    }

    self.waitForExpectations(timeout: 1.0, handler: nil)
  }

  func testDebounce() {
    let initalProducer = Producer<Int, String>()
    let derivedProducer = initalProducer.debounce(interval: 0.5)
    let expectation = self.expectation(description: "completion of derived producer")

    derivedProducer.extractAll { (numbers, stringOrError) in
      XCTAssertEqual([1, 6, 9, 12], numbers)
      XCTAssertEqual("Finished!", stringOrError.success!)
      expectation.fulfill()
    }

    DispatchQueue.global().async {
      usleep(100_000)
      initalProducer.send(1)
      initalProducer.send(2)
      initalProducer.send(3)
      usleep(250_000)
      initalProducer.send(4)
      initalProducer.send(5)
      initalProducer.send(6)
      usleep(250_000)
      initalProducer.send(7)
      initalProducer.send(8)
      initalProducer.send(9)
      usleep(1_000_000)
      initalProducer.send(10)
      initalProducer.send(11)
      initalProducer.send(12)
      usleep(200_000)
      initalProducer.succeed(with: "Finished!")
    }

    self.waitForExpectations(timeout: 5.0)
  }
}
