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

class ChannelTests: XCTestCase {
  
  static let allTests = [
    ("testIterators", testIterators),
    ("testMakeChannel", testMakeChannel),
    ("testOnValueContextual", testOnValueContextual),
    ("testOnValue", testOnValue),
    ("testBuffering0", testBuffering0),
    ("testBuffering1", testBuffering1),
    ("testBuffering2", testBuffering2),
    ("testBuffering3", testBuffering3),
    ("testBuffering10", testBuffering10),
    ("testDescription", testDescription),
    ("testDoubleBind", testDoubleBind),
  ]

  func testIterators() {
    let producer = Producer<Int, String>(bufferSize: 5)
    var iteratorA = producer.makeIterator()
    producer.update(0..<10)
    producer.succeed("finished")
    var iteratorB = producer.makeIterator()

    for index in 0..<10 {
      XCTAssertEqual(iteratorA.next(), index)
    }
    XCTAssertEqual(iteratorA.success, "finished")

    for index in 5..<10 {
      XCTAssertEqual(iteratorB.next(), index)
    }
    XCTAssertEqual(iteratorB.success, "finished")
  }

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

  func testOnValueContextual() {
    let actor = TestActor()

    var updates = [Int]()
    var successValue: String? = nil
    weak var weakProducer: Producer<Int, String>? = nil

    let updatesFixture = pickInts()
    let successValueFixture = "I am working correctly!"

    let successExpectation = self.expectation(description: "success of promise")
    DispatchQueue.global().async {
      let producer = Producer<Int, String>()
      weakProducer = producer
      producer.onUpdate(context: actor) { (actor, update) in
        updates.append(update)
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
        producer.update(updatesFixture)
        producer.succeed(successValueFixture)
      }
    }

    self.waitForExpectations(timeout: 0.2, handler: nil)

    XCTAssertNil(weakProducer)
    XCTAssertEqual(updates, updatesFixture)
    XCTAssertEqual(successValue, successValueFixture)
  }

  func testOnValue() {
    var updates = [Int]()
    var successValue: String? = nil
    weak var weakProducer: Producer<Int, String>? = nil

    let updatesFixture = pickInts()
    let successValueFixture = "I am working correctly!"

    let successExpectation = self.expectation(description: "success of promise")
    let queue = DispatchQueue(label: "testing queue", qos: DispatchQoS(qosClass: pickQoS(), relativePriority: 0))

    DispatchQueue.global().async {
      let producer = Producer<Int, String>()
      weakProducer = producer
      producer.onUpdate(executor: .queue(queue)) { (update) in
        updates.append(update)
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
        producer.update(updatesFixture)
        producer.succeed(successValueFixture)
      }
    }

    self.waitForExpectations(timeout: 0.2, handler: nil)

    XCTAssertNil(weakProducer)
    XCTAssertEqual(updates, updatesFixture)
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
    let updatable = Producer<Int, Void>(bufferSize: bufferSize)

    updatable.update(pickInts())
    updatable.update(fixture.prefix(upTo: bufferSize))

    var updates = [Int]()
    updatable.onUpdate(executor: .queue(queue)) {
      updates.append($0)
    }
    updatable.update(fixture.suffix(from: bufferSize))
    updatable.succeed()

    let expectation = self.expectation(description: "completion of producer")
    updatable.onSuccess(executor: .queue(queue)) {
      expectation.fulfill()
    }
    
    self.waitForExpectations(timeout: 1.0, handler: nil)
    
    XCTAssertEqual(updates, fixture, file: file, line: line)
  }

  func testDescription() {
    let channelA = channel(updates: [1, 2, 3], success: "Done")
    XCTAssertEqual("Succeded(Done) Channel", channelA.description)
    XCTAssertEqual("Succeded(Done) Channel<Int, String>", channelA.debugDescription)

    let channelB: Channel<Int, String> = channel(updates: [1, 2, 3], failure: TestError.testCode)
    XCTAssertEqual("Failed(testCode) Channel", channelB.description)
    XCTAssertEqual("Failed(testCode) Channel<Int, String>", channelB.debugDescription)

    let channelC: Channel<Int, String> = Producer(bufferSize: 5, bufferedUpdates: [1, 2, 3])
    XCTAssertEqual("Incomplete Buffered(3/5) Channel", channelC.description)
    XCTAssertEqual("Incomplete Buffered(3/5) Channel<Int, String>", channelC.debugDescription)

    let channelD: Channel<Int, String> = Producer(bufferSize: 0)
    XCTAssertEqual("Incomplete Channel", channelD.description)
    XCTAssertEqual("Incomplete Channel<Int, String>", channelD.debugDescription)
  }

  func testDoubleBind() {
    let majorActor = DoubleBindTestActor<Int>(initialValue: 3)
    let minorActor = DoubleBindTestActor<Int>(initialValue: 4)
    doubleBind(majorActor.dynamicValue, minorActor.dynamicValue)

    func test(value: Int, file: StaticString = #file, line: UInt = #line) {
      minorActor.internalQueue.sync {
        XCTAssertEqual(minorActor.value, value, file: file, line: line)
      }
      majorActor.internalQueue.sync {
        XCTAssertEqual(majorActor.value, value, file: file, line: line)
      }
    }

    test(value: 3)

    minorActor.value = 6
    test(value: 6)

    minorActor.value = 8
    test(value: 8)

    majorActor.value = 7
    test(value: 7)
  }
}

fileprivate class DoubleBindTestActor<T>: TestActor {
  var dynamicValue: DynamicProperty<T> { return _dynamicValue }
  var value: T {
    get { return _dynamicValue.value }
    set { _dynamicValue.value = newValue }
  }
  private var _dynamicValue: DynamicProperty<T>!

  init(initialValue: T) {
    super.init()
    _dynamicValue = makeDynamicProperty(initialValue)
  }
}
