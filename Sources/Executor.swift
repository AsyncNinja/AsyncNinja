//
//  Copyright (c) 2016 Anton Mironov
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

import Dispatch

/// Executor encapsulates asynchrounous way of execution escaped block.
public struct Executor {
  public typealias Handler = (@escaping (Void) -> Void) -> Void
  private let _impl: ExecutorImpl

  init(impl: ExecutorImpl) {
    _impl = impl
  }

  // Test: ExecutorTests.testCustomHandler
  /// Initialiaes executor with custom handler
  public init(handler: @escaping Handler) {
    _impl = HandlerBasedExecutorImpl(handler: handler)
  }

  func execute(_ block: @escaping (Void) -> Void) {
    _impl.fc_execute(block)
  }

  func execute(after timeout: Double, _ block: @escaping (Void) -> Void) {
    _impl.fc_execute(after: timeout, block)
  }
}

public extension Executor {
  // Test: ExecutorTests.testPrimary
  /// primary executor is primary because it will be used as default value when executor argument is ommited
  static let primary = Executor.default

  /// shortcut to main queue executor
  static let main = Executor.queue(DispatchQueue.main)

  // Test: ExecutorTests.testUserInteractive
  /// shortcut to global concurrent user interactive queue executor
  static let userInteractive = Executor.queue(.userInteractive)

  // Test: ExecutorTests.testUserInitiated
  /// shortcut to global concurrent user initiated queue executor
  static let userInitiated = Executor.queue(.userInitiated)

  // Test: ExecutorTests.testDefault
  /// shortcut to global concurrent default queue executor
  static let `default` = Executor.queue(.default)

  // Test: ExecutorTests.testUtility
  /// shortcut to global concurrent utility queue executor
  static let utility = Executor.queue(.utility)

  // Test: ExecutorTests.testBackground
  /// shortcut to global concurrent background queue executor
  static let background = Executor.queue(.background)

  // Test: ExecutorTests.testImmediate
  /// executes block immediately. Not suitable for long running calculations
  static let immediate = Executor(handler: { $0() })

  /// initializes executor based on specified queue
  // Test: ExecutorTests.testCustomQueue
  static func queue(_ queue: DispatchQueue) -> Executor {
    return Executor(impl: queue)
  }

  /// initializes executor based on global queue with specified QoS class
  // Test: ExecutorTests.testCustomQoS
  static func queue(_ qos: DispatchQoS.QoSClass) -> Executor {
    return Executor.queue(DispatchQueue.global(qos: qos))
  }
}

/// **internal use only**
protocol ExecutorImpl {
  func fc_execute(_ block: @escaping (Void) -> Void)
  func fc_execute(after timeout: Double, _ block: @escaping (Void) -> Void)
}

extension DispatchQueue : ExecutorImpl {
  func fc_execute(_ block: @escaping (Void) -> Void) {
    self.async(execute: block)
  }

  func fc_execute(after timeout: Double, _ block: @escaping (Void) -> Void) {
    let wallDeadline = DispatchWallTime.now() + .nanoseconds(Int(timeout * 1000_000_000))
    self.asyncAfter(wallDeadline: wallDeadline, execute: block)
  }
}

final class HandlerBasedExecutorImpl : ExecutorImpl {
  public typealias Handler = (@escaping (Void) -> Void) -> Void
  private let _handler: Handler

  init(handler: @escaping Handler) {
    _handler = handler
  }

  func fc_execute(_ block: @escaping (Void) -> Void) {
    _handler(block)
  }

  func fc_execute(after timeout: Double, _ block: @escaping (Void) -> Void) {
    let deadline = DispatchWallTime.now() + .nanoseconds(Int(timeout * 1000_000_000))
    DispatchQueue.global(qos: .default).asyncAfter(wallDeadline: deadline) {
      self.fc_execute(block)
    }
  }
}
