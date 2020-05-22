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

import Dispatch

/// Executor encapsulates asynchrounous way of execution escaped block.
public struct Executor {
  /// Handler that encapsulates asynchrounous way of execution escaped block
  public typealias Handler = (@escaping () -> Void) -> Void
  private let _impl: ExecutorImpl
  private let _nesting: Int
  var dispatchQueueBasedExecutor: Executor {
    switch _impl.asyncNinja_representedDispatchQueue {
    case .none: return .primary
    case .some: return self
    }
  }
  var representedDispatchQueue: DispatchQueue? {
    return _impl.asyncNinja_representedDispatchQueue
  }
  var unnested: Executor {
    return Executor(impl: _impl, nesting: 0)
  }
  var nested: Executor? {
    return _nesting < 64 ? Executor(impl: _impl, nesting: _nesting + 1) : nil
  }

  /// Initializes executor with specified implementation
  ///
  /// - Parameter impl: implementation of executor
  fileprivate init(impl: ExecutorImpl, nesting: Int) {
    _impl = impl
    _nesting = nesting
  }

  /// Initialiaes executor with custom handler
  ///
  /// - Parameters:
  ///   - handler: encapsulates asynchrounous way of execution escaped block
  public init(relaxAsyncWhenLaunchingFrom: ObjectIdentifier? = nil, handler: @escaping Handler) {
    // Test: ExecutorTests.testCustomHandler
    _impl = HandlerBasedExecutorImpl(relaxAsyncWhenLaunchingFrom: relaxAsyncWhenLaunchingFrom, handler: handler)
    _nesting = 0
  }

  /// Schedules specified block for execution
  ///
  /// - Parameter original: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  /// - Parameter block: to execute
  func execute(from original: Executor?, _ block: @escaping (_ original: Executor) -> Void) {
    if case let .some(newOrigin) = original?.nested,
      _impl.asyncNinja_canImmediatelyExecute(from: newOrigin._impl) {
      block(newOrigin)
    } else {
      _impl.asyncNinja_execute { () -> Void in block(self.unnested) }
    }
  }

  /// Schedules specified block for execution. Execution will be asynchronous
  /// on all DispatchQueue based Executors (like main or default global).
  /// Immediate executor will do it synchronously.
  ///
  /// - Parameter block: to execute
  func schedule( _ block : @escaping (_ original: Executor) -> Void) {
    _impl.asyncNinja_execute { block(self.unnested) }
  }

  func execute<T>(from original: Executor?, value: T, _ block: @escaping (_ value: T, _ original: Executor) -> Void) {
    if case let .some(newOrigin) = original?.nested,
      _impl.asyncNinja_canImmediatelyExecute(from: newOrigin._impl) {
      block(value, newOrigin)
    } else {
      _impl.asyncNinja_execute { () -> Void in block(value, self.unnested) }
    }
  }

  /// Schedules specified block for execution after timeout
  ///
  /// - Parameters:
  ///   - timeout: to schedule execution of the block after
  ///   - block: to execute
  func execute(after timeout: Double, _ block: @escaping (_ original: Executor) -> Void) {
    _impl.asyncNinja_execute(after: timeout) { () -> Void in block(self.unnested) }
  }
}

// MARK: - known executors

public extension Executor {
  // Test: ExecutorTests.testPrimary
  /// primary executor is primary because it will be used
  /// as default value when executor argument is ommited
  static let primary = Executor(impl: PrimaryExecutorImpl(), nesting: 0)

  /// shortcut to the main queue executor
  static let main = Executor(impl: MainExecutorImpl(), nesting: 0)

  // Test: ExecutorTests.testUserInteractive
  /// shortcut to the global concurrent user interactive queue executor
  static let userInteractive = Executor.queue(.userInteractive)

  // Test: ExecutorTests.testUserInitiated
  /// shortcut to the global concurrent user initiated queue executor
  static let userInitiated = Executor.queue(.userInitiated)

  // Test: ExecutorTests.testDefault
  /// shortcut to the global concurrent default queue executor
  static let `default` = Executor.queue(.default)

  // Test: ExecutorTests.testUtility
  /// shortcut to the global concurrent utility queue executor
  static let utility = Executor.queue(.utility)

  // Test: ExecutorTests.testBackground
  /// shortcut to the  global concurrent background queue executor
  static let background = Executor.queue(.background)

  // Test: ExecutorTests.testImmediate
  /// executes block immediately. Not suitable for long running calculations
  static let immediate = Executor(impl: ImmediateExecutorImpl(), nesting: 0)

  /// initializes executor based on specified queue
  ///
  /// - Parameter queue: to execute submitted blocks on
  /// - Returns: executor
  static func queue(_ queue: DispatchQueue) -> Executor {
    // Test: ExecutorTests.testCustomQueue
    return Executor(queue: queue)
  }

  /// initializes executor based on specified queue
  ///
  /// - Parameter queue: to execute submitted blocks on
  init(queue: DispatchQueue) {
    self.init(impl: queue, nesting: 0)
  }

  // Test: ExecutorTests.testCustomQoS
  /// initializes executor based on global queue with specified QoS class
  ///
  /// - Parameter qos: quality of service for submitted blocks
  /// - Returns: executor
  static func queue(_ qos: DispatchQoS.QoSClass) -> Executor {
    return Executor(qos: qos)
  }

  /// initializes executor based on global queue with specified QoS class
  ///
  /// - Parameter qos: quality of service for submitted blocks
  init(qos: DispatchQoS.QoSClass) {
    self.init(queue: .global(qos: qos))
  }
}

// MARK: - implementations

/// **internal use only**
protocol ExecutorImpl: class {
  var asyncNinja_representedDispatchQueue: DispatchQueue? { get }
  var asyncNinja_canImmediatelyExecuteOnPrimaryExecutor: Bool { get }

  func asyncNinja_execute(_ block: @escaping () -> Void)
  func asyncNinja_execute(after timeout: Double, _ block: @escaping () -> Void)
  func asyncNinja_canImmediatelyExecute(from impl: ExecutorImpl) -> Bool
}

private class PrimaryExecutorImpl: ExecutorImpl {
  let queue = DispatchQueue.global()

  var asyncNinja_representedDispatchQueue: DispatchQueue? { return queue }
  var asyncNinja_canImmediatelyExecuteOnPrimaryExecutor: Bool { return true }

  func asyncNinja_execute(_ block: @escaping () -> Void) {
    queue.async(execute: block)
  }

  func asyncNinja_execute(after timeout: Double, _ block: @escaping () -> Void) {
    let wallDeadline = DispatchWallTime.now().adding(seconds: timeout)
    queue.asyncAfter(wallDeadline: wallDeadline, execute: block)
  }

  func asyncNinja_canImmediatelyExecute(from impl: ExecutorImpl) -> Bool {
    return impl.asyncNinja_canImmediatelyExecuteOnPrimaryExecutor
  }
}

private class MainExecutorImpl: ExecutorImpl {
  let queue = DispatchQueue.main

  var asyncNinja_representedDispatchQueue: DispatchQueue? { return queue }
  var asyncNinja_canImmediatelyExecuteOnPrimaryExecutor: Bool { return true }

  func asyncNinja_execute(_ block: @escaping () -> Void) {
    queue.async(execute: block)
  }

  func asyncNinja_execute(after timeout: Double, _ block: @escaping () -> Void) {
    let wallDeadline = DispatchWallTime.now().adding(seconds: timeout)
    queue.asyncAfter(wallDeadline: wallDeadline, execute: block)
  }

  func asyncNinja_canImmediatelyExecute(from impl: ExecutorImpl) -> Bool {
    return impl === self
  }
}

private class ImmediateExecutorImpl: ExecutorImpl {
  var asyncNinja_representedDispatchQueue: DispatchQueue? { return nil }
  var asyncNinja_canImmediatelyExecuteOnPrimaryExecutor: Bool { return true }

  func asyncNinja_execute(_ block: @escaping () -> Void) {
    block()
  }

  func asyncNinja_execute(after timeout: Double, _ block: @escaping () -> Void) {
    let deadline = DispatchWallTime.now().adding(seconds: timeout)
    DispatchQueue.global(qos: .default)
      .asyncAfter(wallDeadline: deadline, execute: block)
  }

  func asyncNinja_canImmediatelyExecute(from impl: ExecutorImpl) -> Bool {
    return true
  }
}

private class HandlerBasedExecutorImpl: ExecutorImpl {
  public typealias Handler = (@escaping () -> Void) -> Void
  private let _handler: Handler
  private let _relaxAsyncWhenLaunchingFrom: ObjectIdentifier?

  var asyncNinja_representedDispatchQueue: DispatchQueue? { return nil }
  var asyncNinja_canImmediatelyExecuteOnPrimaryExecutor: Bool { return false }

  init(relaxAsyncWhenLaunchingFrom: ObjectIdentifier?, handler: @escaping Handler) {
    _relaxAsyncWhenLaunchingFrom = relaxAsyncWhenLaunchingFrom
    _handler = handler
  }

  func asyncNinja_execute(_ block: @escaping () -> Void) {
    _handler(block)
  }

  func asyncNinja_execute(after timeout: Double, _ block: @escaping () -> Void) {
    let deadline = DispatchWallTime.now().adding(seconds: timeout)
    let handler = _handler
    DispatchQueue.global(qos: .default)
      .asyncAfter(wallDeadline: deadline) {
        handler(block)
    }
  }

  func asyncNinja_canImmediatelyExecute(from impl: ExecutorImpl) -> Bool {
    if let other = impl as? HandlerBasedExecutorImpl {
      return _relaxAsyncWhenLaunchingFrom == other._relaxAsyncWhenLaunchingFrom
    } else {
      return false
    }
  }
}
