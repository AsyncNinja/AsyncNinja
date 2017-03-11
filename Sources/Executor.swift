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
  public typealias Handler = (@escaping (Void) -> Void) -> Void
  private let _impl: ExecutorImpl
  private let _strictAsync: Bool
  var dispatchQueueBasedExecutor: Executor {
    switch _impl.asyncNinja_representedDispatchQueue() {
    case .none: return .primary
    case .some: return self
    }
  }
  var representedDispatchQueue: DispatchQueue? {
    return _impl.asyncNinja_representedDispatchQueue()
  }

  /// Initializes executor with specified implementation
  ///
  /// - Parameter impl: implementation of executor
  fileprivate init(impl: ExecutorImpl, strictAsync: Bool = false) {
    _impl = impl
    _strictAsync = strictAsync
  }

  /// Initialiaes executor with custom handler
  ///
  /// - Parameters:
  ///   - handler: encapsulates asynchrounous way of execution escaped block
  public init(strictAsync: Bool = false, handler: @escaping Handler) {
    // Test: ExecutorTests.testCustomHandler
    _impl = HandlerBasedExecutorImpl(handler: handler)
    _strictAsync = strictAsync
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
    guard let original = original else {
      _impl.asyncNinja_execute { block(self) }
      return;
    }

    if _strictAsync {
      _impl.asyncNinja_execute { block(self) }
    } else if _impl is ImmediateExecutorImpl {
      block(original)
    } else if _impl === original._impl {
      block(self)
    } else if _impl is PrimaryExecutorImpl,
      original._impl.asyncNinja_canImmediatelyExecuteFromPrimaryExecutor() {
      block(original)
    } else {
      _impl.asyncNinja_execute { block(self) }
    }
  }

  /// Schedules specified block for execution after timeout
  ///
  /// - Parameters:
  ///   - timeout: to schedule execution of the block after
  ///   - block: to execute
  func execute(after timeout: Double, _ block: @escaping (_ original: Executor) -> Void) {
    _impl.asyncNinja_execute(after: timeout) { block(self) }
  }
}

// MARK: - known executors

public extension Executor {
  // Test: ExecutorTests.testPrimary
  /// primary executor is primary because it will be used
  /// as default value when executor argument is ommited
  static let primary = Executor(impl: PrimaryExecutorImpl(), strictAsync: false)

  /// shortcut to the main queue executor
  static let main = Executor(impl: MainExecutorImpl(), strictAsync: false)

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
  static let immediate = Executor(impl: ImmediateExecutorImpl(), strictAsync: false)

  /// initializes executor based on specified queue
  ///
  /// - Parameter queue: to execute submitted blocks on
  /// - Returns: executor
  static func queue(_ queue: DispatchQueue, strictAsync: Bool = false) -> Executor {
    // Test: ExecutorTests.testCustomQueue
    return Executor(impl: queue, strictAsync: strictAsync)
  }

  // Test: ExecutorTests.testCustomQoS
  /// initializes executor based on global queue with specified QoS class
  ///
  /// - Parameter qos: quality of service for submitted blocks
  /// - Returns: executor
  static func queue(_ qos: DispatchQoS.QoSClass, strictAsync: Bool = true) -> Executor {
    return Executor.queue(.global(qos: qos), strictAsync: strictAsync)
  }
}

// MARK: implementations

/// **internal use only**
fileprivate protocol ExecutorImpl: class {
  func asyncNinja_execute(_ block: @escaping (Void) -> Void)
  func asyncNinja_execute(after timeout: Double, _ block: @escaping (Void) -> Void)
  func asyncNinja_representedDispatchQueue() -> DispatchQueue?
  func asyncNinja_canImmediatelyExecuteFromPrimaryExecutor() -> Bool
}

private class PrimaryExecutorImpl: ExecutorImpl {
  let queue = DispatchQueue.global()

  func asyncNinja_execute(_ block: @escaping (Void) -> Void) {
    queue.async(execute: block)
  }

  func asyncNinja_execute(after timeout: Double, _ block: @escaping (Void) -> Void) {
    let wallDeadline = DispatchWallTime.now().adding(seconds: timeout)
    queue.asyncAfter(wallDeadline: wallDeadline, execute: block)
  }

  func asyncNinja_representedDispatchQueue() -> DispatchQueue? {
    return queue
  }

  func asyncNinja_canImmediatelyExecuteFromPrimaryExecutor() -> Bool {
    return true
  }
}

private class MainExecutorImpl: ExecutorImpl {
  let queue = DispatchQueue.main

  func asyncNinja_execute(_ block: @escaping (Void) -> Void) {
    queue.async(execute: block)
  }

  func asyncNinja_execute(after timeout: Double, _ block: @escaping (Void) -> Void) {
    let wallDeadline = DispatchWallTime.now().adding(seconds: timeout)
    queue.asyncAfter(wallDeadline: wallDeadline, execute: block)
  }

  func asyncNinja_representedDispatchQueue() -> DispatchQueue? {
    return queue
  }

  func asyncNinja_canImmediatelyExecuteFromPrimaryExecutor() -> Bool {
    return true
  }
}

extension DispatchQueue: ExecutorImpl {
  fileprivate func asyncNinja_execute(_ block: @escaping (Void) -> Void) {
    self.async(execute: block)
  }

  fileprivate func asyncNinja_execute(after timeout: Double, _ block: @escaping (Void) -> Void) {
    let wallDeadline = DispatchWallTime.now().adding(seconds: timeout)
    self.asyncAfter(wallDeadline: wallDeadline, execute: block)
  }

  func asyncNinja_representedDispatchQueue() -> DispatchQueue? {
    return self
  }

  func asyncNinja_canImmediatelyExecuteFromPrimaryExecutor() -> Bool {
    return false
  }
}

fileprivate class ImmediateExecutorImpl: ExecutorImpl {
  func asyncNinja_execute(_ block: @escaping (Void) -> Void) {
    block()
  }

  func asyncNinja_execute(after timeout: Double, _ block: @escaping (Void) -> Void) {
    let deadline = DispatchWallTime.now().adding(seconds: timeout)
    DispatchQueue.global(qos: .default).asyncAfter(wallDeadline: deadline) {
      block()
    }
  }

  func asyncNinja_representedDispatchQueue() -> DispatchQueue? {
    return nil
  }

  func asyncNinja_canImmediatelyExecuteFromPrimaryExecutor() -> Bool {
    return true
  }
}

fileprivate class HandlerBasedExecutorImpl: ExecutorImpl {
  public typealias Handler = (@escaping (Void) -> Void) -> Void
  private let _handler: Handler

  init(handler: @escaping Handler) {
    _handler = handler
  }

  func asyncNinja_execute(_ block: @escaping (Void) -> Void) {
    _handler(block)
  }

  func asyncNinja_execute(after timeout: Double, _ block: @escaping (Void) -> Void) {
    let deadline = DispatchWallTime.now().adding(seconds: timeout)
    DispatchQueue.global(qos: .default).asyncAfter(wallDeadline: deadline) {
      self.asyncNinja_execute(block)
    }
  }

  func asyncNinja_representedDispatchQueue() -> DispatchQueue? {
    return nil
  }

  func asyncNinja_canImmediatelyExecuteFromPrimaryExecutor() -> Bool {
    return false
  }
}
