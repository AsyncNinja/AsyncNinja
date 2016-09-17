//
//  TestUtilities.swift
//  AsyncNinja
//
//  Created by Anton Mironov on 16.09.16.
//
//

import XCTest
import Dispatch
@testable import AsyncNinja
#if os(Linux)
  import Glibc
#endif

func assert(on queue: DispatchQueue) {
  if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
    dispatchPrecondition(condition: .onQueue(queue))
  } else {
    // TODO
  }
}

func assert(qos: DispatchQoS.QoSClass) {
  if #available(macOS 10.12, iOS 10.0, tvOS 10.0, *) {
    dispatchPrecondition(condition: .onQueue(DispatchQueue.global(qos: qos)))
  } else {
    // TODO
  }
}

func assert(actor: TestActor) {
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

func pickInt(max: Int = 100) -> Int {
  #if os(Linux)
    return numericCast(random()) % max
  #elseif os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    return numericCast(arc4random()) % max
  #else
  #endif
}

enum TestError : Error {
  case testCode
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

class TestActor : ExecutionContext, ReleasePoolOwner {
  let internalQueue = DispatchQueue(label: "internal queue", attributes: [])
  var executor: Executor { return .queue(self.internalQueue) }
  let releasePool = ReleasePool()
}

func eval<Result>(invoking body: () throws -> Result) rethrows -> Result {
  return try body()
}
