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

/// represents values that periodically arrive followed by failure of final value that completes Channel. Channel oftenly represents result of long running task that is not yet arrived and flow of some intermediate results.
public class Channel<PeriodicValue, SuccessValue>: Finite, Sequence {
  public typealias Value = ChannelValue<PeriodicValue, SuccessValue>
  public typealias Handler = ChannelHandler<PeriodicValue, SuccessValue>
  public typealias Iterator = ChannelIterator<PeriodicValue, SuccessValue>

  /// final falue of channel. Returns nil if channel is not complete yet
  public var finalValue: Fallible<SuccessValue>? { assertAbstract() }

  /// amount of currently stored periodics
  public var bufferSize: Int { assertAbstract() }

  /// maximal amount of periodics store
  public var maxBufferSize: Int { assertAbstract() }

  init() { }

  /// **internal use only**
  final public func makeFinalHandler(executor: Executor,
                                     block: @escaping (Fallible<SuccessValue>) -> Void
    ) -> Handler? {
    return self.makeHandler(executor: executor) {
      if case .final(let value) = $0 { block(value) }
    }
  }

  /// **internal use only**
  final public func makePeriodicHandler(executor: Executor,
                                        block: @escaping (PeriodicValue) -> Void
    ) -> Handler? {
    return self.makeHandler(executor: executor) {
      if case .periodic(let value) = $0 { block(value) }
    }
  }

  /// **internal use only**
  public func makeHandler(executor: Executor,
                          block: @escaping (Value) -> Void) -> Handler? {
    assertAbstract()
  }

  /// Makes an iterator that allows synchronous iteration over periodic values of the channel
  public func makeIterator() -> Iterator {
    assertAbstract()
  }
  
  /// **Internal use only**.
  public func insertToReleasePool(_ releasable: Releasable) {
    assertAbstract()
  }
}

// MARK: - Description

extension Channel: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of this instance.
  public var description: String {
    return description(withBody: "Channel")
  }

  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    return description(withBody: "Channel<\(PeriodicValue.self), \(SuccessValue.self)>")
  }

  /// **internal use only**
  private func description(withBody body: String) -> String {
    switch finalValue {
    case .some(.success(let value)):
      return "Succeded(\(value)) \(body)"
    case .some(.failure(let error)):
      return "Failed(\(error)) \(body)"
    case .none:
      let currentBufferSize = self.bufferSize
      let maxBufferSize = self.maxBufferSize
      let bufferedString = (0 == maxBufferSize)
        ? ""
        : " Buffered(\(currentBufferSize)/\(maxBufferSize))"
      return "Incomplete\(bufferedString) \(body)"
    }
  }
}

// MARK: - Subscriptions

public extension Channel {
  /// Subscribes for buffered and new values (both periodic and final) for the channel
  ///
  /// - Parameters:
  ///   - executor: to execute block on
  ///   - block: to execute. Will be called multiple times
  ///   - value: received by the channel
  func onValue(executor: Executor = .primary, block: @escaping (_ value: Value) -> Void) {
    let handler = self.makeHandler(executor: executor, block: block)
    self.insertHandlerToReleasePool(handler)
  }

  /// Subscribes for buffered and new values (both periodic and final) for the channel
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need
  ///     to override an executor provided by the context
  ///   - block: to execute. Will be called multiple times
  ///   - strongContext: context restored from weak reference to specified context
  ///   - value: received by the channel
  func onValue<C: ExecutionContext>(context: C,
               executor: Executor? = nil,
               block: @escaping (_ strongContext: C, _ value: Value) -> Void) {
    let executor_ = executor ?? context.executor
    let handler = self.makeHandler(executor: executor_) {
      [weak context] (value) in
      guard let context = context else { return }
      block(context, value)
    }

    if let handler = handler {
      context.releaseOnDeinit(handler)
    }
  }
  
  /// Subscribes for buffered and new periodic values for the channel
  ///
  /// - Parameters:
  ///   - executor: to execute block on
  ///   - block: to execute. Will be called multiple times
  ///   - periodicValue: received by the channel
  func onPeriodic(executor: Executor = .primary,
                  block: @escaping (_ periodicValue: PeriodicValue) -> Void) {
    self.onValue(executor: executor) { (value) in
      switch value {
      case let .periodic(periodic):
        block(periodic)
      case .final: nop()
      }
    }
  }

  /// Subscribes for buffered and new periodic values for the channel
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need
  ///     to override an executor provided by the context
  ///   - block: to execute. Will be called multiple times
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodicValue: received by the channel
  func onPeriodic<C: ExecutionContext>(context: C,
                  executor: Executor? = nil,
                  block: @escaping (_ strongContext: C, _ periodicValue: PeriodicValue) -> Void) {
    self.onValue(context: context, executor: executor) { (context, value) in
      switch value {
      case let .periodic(periodic):
        block(context, periodic)
      case .final: nop()
      }
    }
  }

  /// Subscribes for all buffered and new values (both periodic and final) for the channel
  ///
  /// - Parameters:
  ///   - executor: to execute block on
  ///   - block: to execute. Will be called once with all values
  ///   - periodicValues: all received by the channel
  ///   - finalValue: received by the channel
  func extractAll(executor: Executor = .primary,
                  block: @escaping (_ periodicValues: [PeriodicValue], _ finalValue: Fallible<SuccessValue>) -> Void) {
    var periodics = [PeriodicValue]()
    let executor_ = executor.makeDerivedSerialExecutor()
    self.onValue(executor: executor_) { (value) in
      switch value {
      case let .periodic(periodic):
        periodics.append(periodic)
      case let .final(final):
        block(periodics, final)
      }
    }
  }

  /// Subscribes for all buffered and new values (both periodic and final) for the channel
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need
  ///     to override an executor provided by the context
  ///   - block: to execute. Will be called once with all values
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodicValues: all received by the channel
  ///   - finalValue: received by the channel
  func extractAll<C: ExecutionContext>(context: C,
                  executor: Executor? = nil,
                  block: @escaping (_ strongContext: C, _ periodicValues: [PeriodicValue], _ finalValue: Fallible<SuccessValue>) -> Void) {
    var periodics = [PeriodicValue]()
    let executor_ = (executor ?? context.executor).makeDerivedSerialExecutor()
    self.onValue(context: context, executor: executor_) { (context, value) in
      switch value {
      case let .periodic(periodic):
        periodics.append(periodic)
      case let .final(final):
        block(context, periodics, final)
      }
    }
  }

  /// Synchronously waits for channel to complete. Returns all periodic and final values
  func waitForAll() -> (periodics: [PeriodicValue], final: Fallible<SuccessValue>) {
    return (self.map { $0 }, self.finalValue!)
  }
}

// MARK: - Iterators

/// Synchronously iterates over each periodic value of channel
public struct ChannelIterator<PeriodicValue, SuccessValue>: IteratorProtocol  {
  public typealias Element = PeriodicValue
  private var _implBox: Box<ChannelIteratorImpl<PeriodicValue, SuccessValue>> // want to have reference to reference, because impl may actually be retained by some handler

  /// final value of the channel. Will be available as soon as the channel completes.
  public var finalValue: Fallible<SuccessValue>? { return _implBox.value.finalValue }

  /// **internal use only** Designated initializer
  init(impl: ChannelIteratorImpl<PeriodicValue, SuccessValue>) {
    _implBox = Box(impl)
  }

  /// fetches next value from the channel.
  /// Waits for the next value to appear.
  /// Returns nil when then channel completes
  public mutating func next() -> PeriodicValue? {
    if !isKnownUniquelyReferenced(&_implBox) {
      _implBox = Box(_implBox.value.clone())
    }
    return _implBox.value.next()
  }
}

/// **Internal use only**
class ChannelIteratorImpl<PeriodicValue, SuccessValue>  {
  public typealias Element = PeriodicValue
  var finalValue: Fallible<SuccessValue>? { assertAbstract() }

  init() { }

  public func next() -> PeriodicValue? {
    assertAbstract()
  }

  func clone() -> ChannelIteratorImpl<PeriodicValue, SuccessValue> {
    assertAbstract()
  }
}

/// Value reveived by channel
public enum ChannelValue<T, U> {
  public typealias PeriodicValue = T
  public typealias SuccessValue = U

  /// A kind of value that can be received multiple times be for the final one
  case periodic(PeriodicValue)

  /// A kind of value that can be received once and completes the channel
  case final(Fallible<SuccessValue>)
}

// MARK: - Handlers

/// **internal use only** Wraps each block submitted to the channel
/// to provide required memory management behavior
final public class ChannelHandler<PeriodicValue, SuccessValue> {
  public typealias Value = ChannelValue<PeriodicValue, SuccessValue>

  let executor: Executor
  let block: (Value) -> Void
  var owner: Channel<PeriodicValue, SuccessValue>?

  /// Designated initializer of ChannelHandler
  public init(executor: Executor, block: @escaping (Value) -> Void, owner: Channel<PeriodicValue, SuccessValue>) {
    self.executor = executor
    self.block = block
    self.owner = owner
  }

  func handle(_ value: Value) {
    let block = self.block
    self.executor.execute { block(value) }
  }

  func releaseOwner() {
    self.owner = nil
  }
}
