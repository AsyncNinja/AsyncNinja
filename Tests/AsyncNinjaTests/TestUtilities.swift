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

func assert(actor: Actor, file: StaticString = #file, line: UInt = #line) {
  // TODO: use file and line
  if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
    dispatchPrecondition(condition: .onQueue(actor.internalQueue))
  } else {
    // TODO
  }
}

extension XCTestCase {
  func multiTest(repeating: Int = 1, _ test: @escaping () -> Void) {
    let globalQueue = DispatchQueue.global()
    let configs: [(threads: Int, tests: Int)] = [ (1, 8), (2, 4), (4, 2), (8, 1) ]

    for _ in 0..<repeating {
      for config in configs {
        let autoreleaseFrequency: DispatchQueue.AutoreleaseFrequency
        if #available(OSX 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
          autoreleaseFrequency = .workItem
        } else {
          autoreleaseFrequency = .inherit
        }
        let localQueue = DispatchQueue(label: "local queue",
                                       qos: .default,
                                       attributes: [.concurrent],
                                       autoreleaseFrequency: autoreleaseFrequency,
                                       target: globalQueue)

        for _ in 0..<config.threads {
          localQueue.async {
            for _ in 0..<config.tests {
              test()
            }
          }
        }

        localQueue.sync(flags: [.barrier]) {}
      }
    }
  }
}

private struct Constants {
  static let availableQosClassses: [DispatchQoS.QoSClass] = [
    .default,
    .userInitiated,
    .userInteractive
  ]
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
    return numericCast(arc4random() >> 1) % max
  #else
    fatalError()
  #endif
}

func eval<Result>(_ body: () throws -> Result) rethrows -> Result {
  return try body()
}

func mysleep(_ duration: Double) {
  #if true
    usleep(UInt32(duration * 1_000_000))
  #else
    let (seconds, fraction) = modf(duration)
    var requestedTime = timespec(tv_sec: Int(seconds), tv_nsec: Int(fraction * 1_000_000_000))
    var remainingTime = timespec()
    assert(0 == nanosleep(&requestedTime, &remainingTime))
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

protocol Actor: ExecutionContext {
    var internalQueue: DispatchQueue { get }
}

class TestActor: Actor, ReleasePoolOwner {
  let internalQueue = DispatchQueue(label: "internal queue", attributes: [])
  var executor: Executor { return .queue(self.internalQueue) }
  let releasePool = ReleasePool()
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

class TestObjCActor: NSObject, Actor, ObjCInjectedRetainer {
    let internalQueue = DispatchQueue(label: "internal queue", attributes: [])
    var executor: Executor { return .queue(self.internalQueue) }
}

#endif
