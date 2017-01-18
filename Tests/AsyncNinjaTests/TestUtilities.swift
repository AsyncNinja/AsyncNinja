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

func assert(on queue: DispatchQueue, file: StaticString = #file, line: UInt = #line) {
  // TODO: use file and line
  if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
    dispatchPrecondition(condition: .onQueue(queue))
  } else {
    // TODO
  }
}

func assert(qos: DispatchQoS.QoSClass, file: StaticString = #file, line: UInt = #line) {
  // TODO: use file and line
  if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
    dispatchPrecondition(condition: .onQueue(DispatchQueue.global(qos: qos)))
  } else {
    // TODO
  }
}

func assert(nonGlobalQoS: DispatchQoS.QoSClass, file: StaticString = #file, line: UInt = #line) {
  // TODO: use file and line
  // TODO: figure out qos of current queue
}

func assert(actor: TestActor, file: StaticString = #file, line: UInt = #line) {
  // TODO: use file and line
  if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
    dispatchPrecondition(condition: .onQueue(actor.internalQueue))
  } else {
    // TODO
  }
}

fileprivate struct Constants {
  static let availableQosClassses: [DispatchQoS.QoSClass] = [.background, .utility, .default, .userInitiated, .userInteractive, ]
}

func pickQoS() -> DispatchQoS.QoSClass {
  return Constants.availableQosClassses[pickInt(max: Constants.availableQosClassses.count)]
}

func pickInts(count: Int = 5, max: Int = 100) -> [Int] {
  return (0..<count).map { _ in pickInt(max: max) }
}

func pickInt(max: Int = 100) -> Int {
  #if os(Linux)
    return numericCast(random()) % max
  #elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    return numericCast(arc4random()) % max
  #else
    fatalError()
  #endif
}

enum TestError: Error {
  case testCode
  case otherCode
}

func square(_ value: Int) -> Int {
  return value * value
}

func square_success(_ value: Int) throws -> Int {
  return value * value
}

func square_failure(_ value: Int) throws -> Int {
  throw TestError.testCode
}

class TestActor: ExecutionContext, ReleasePoolOwner {
  let internalQueue = DispatchQueue(label: "internal queue", attributes: [])
  var executor: Executor { return .queue(self.internalQueue, isSerial: true) }
  let releasePool = ReleasePool()

  deinit {
    print("Hello!")
  }
}

func eval<Result>(invoking body: () throws -> Result) rethrows -> Result {
  return try body()
}
