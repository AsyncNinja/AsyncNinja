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

public class Channel<PeriodicValue, FinalValue> : Finite {
  public typealias Value = ChannelValue<PeriodicValue, FinalValue>
  public typealias Handler = ChannelHandler<PeriodicValue, FinalValue>
  public typealias PeriodicHandler = Handler
  public typealias FinalHandler = Handler
  public typealias Iterator = ChannelIterator<PeriodicValue, FinalValue>

  /// final falue of channel. Returns nil if channel is not complete yet
  public var finalValue: Fallible<FinalValue>? {
    /* abstact */
    fatalError()
  }

  /// amount of currently stored periodics
  public var bufferSize: Int {
    /* abstact */
    fatalError()
  }

  /// maximal amount of periodics store
  public var maxBufferSize: Int {
    /* abstact */
    fatalError()
  }

  init() { }

  /// **internal use only**
  final public func makeFinalHandler(executor: Executor,
                                     block: @escaping (Fallible<FinalValue>) -> Void) -> Handler? {
    return self.makeHandler(executor: executor) {
      if case .final(let value) = $0 { block(value) }
    }
  }

  /// **internal use only**
  final public func makePeriodicHandler(executor: Executor,
                                          block: @escaping (PeriodicValue) -> Void) -> Handler? {
    return self.makeHandler(executor: executor) {
      if case .periodic(let value) = $0 { block(value) }
    }
  }

  /// **internal use only**
  public func makeHandler(executor: Executor,
                          block: @escaping (Value) -> Void) -> Handler? {
    assertAbstract()
  }

  /// Makes an iterator that allows synchonus iteration over periodic values of the channel
  public func makeIterator() -> Iterator {
    assertAbstract()
  }
  
  /// **Internal use only**.
  public func insertToReleasePool(_ releasable: Releasable) {
    assertAbstract()
  }
}

public extension Channel {
  /// Subscribes for buffered and new values (both periodic and final) for the channel
  ///
  /// - Parameters:
  ///   - executor: to execute block on
  ///   - block: to execute. Will be called multiple times
  ///   - value: received by the channel
  func onValue(executor: Executor = .primary, block: @escaping (_ value: Value) -> Void) {
    let handler = self.makeHandler(executor: executor, block: block)
    
    if let handler = handler {
      self.insertToReleasePool(handler)
    }
  }

  /// Subscribes for buffered and new values (both periodic and final) for the channel
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor. Do not use this argument if you do not need to override executor
  ///   - block: to execute. Will be called multiple times
  ///   - strongContext: context restored from weak reference to specified context
  ///   - value: received by the channel
  func onValue<U: ExecutionContext>(context: U,
               executor: Executor? = nil,
               block: @escaping (_ strongContext: U, _ value: Value) -> Void) {
    let handler = self.makeHandler(executor: executor ?? context.executor) { [weak context] (value) in
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
  func onPeriodic(executor: Executor = .primary, block: @escaping (_ periodicValue: PeriodicValue) -> Void) {
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
  ///   - executor: override of `ExecutionContext`s executor. Do not use this argument if you do not need to override executor
  ///   - block: to execute. Will be called multiple times
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodicValue: received by the channel
  func onPeriodic<U: ExecutionContext>(context: U,
                  executor: Executor? = nil,
                  block: @escaping (_ strongContext: U, _ periodicValue: PeriodicValue) -> Void) {
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
  func extractAll(
    executor: Executor = .primary,
    block: @escaping (_ periodicValues: [PeriodicValue], _ finalValue: Fallible<FinalValue>) -> Void) {
    var locking = makeLocking()
    var periodics = [PeriodicValue]()
    let handler = self.makeHandler(executor: executor) { (value) in
      locking.lock()
      defer { locking.unlock() }
      switch value {
      case let .periodic(periodic):
        periodics.append(periodic)
      case let .final(final):
        block(periodics, final)
      }
    }

    if let handler = handler {
      self.insertToReleasePool(handler)
    }
  }

  /// Subscribes for all buffered and new values (both periodic and final) for the channel
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor. Do not use this argument if you do not need to override executor
  ///   - block: to execute. Will be called once with all values
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodicValues: all received by the channel
  ///   - finalValue: received by the channel
  func extractAll<U: ExecutionContext>(context: U,
                  executor: Executor? = nil,
                  block: @escaping (_ strongContext: U, _ periodicValues: [PeriodicValue], _ finalValue: Fallible<FinalValue>) -> Void) {
    var locking = makeLocking()
    var periodics = [PeriodicValue]()
    let handler = self.makeHandler(executor: executor ?? context.executor) { [weak context] (value) in
      locking.lock()
      defer { locking.unlock() }
      switch value {
      case let .periodic(periodic):
        periodics.append(periodic)
      case let .final(final):
        if let context = context {
          block(context, periodics, final)
        }
      }
    }

    if let handler = handler {
      context.releaseOnDeinit(handler)
    }
  }

  /// Synchronously waits for channel to complete. Returns all periodic and final values
  func waitForAll() -> (periodics: [PeriodicValue], final: Fallible<FinalValue>) {
    var periodics = [PeriodicValue]()
    var iterator = self.makeIterator()
    while let periodic = iterator.next() {
      periodics.append(periodic)
    }
    return (periodics, iterator.finalValue!)
  }
}

/// Synchronously iterates over each periodic value of channel
public struct ChannelIterator<PeriodicValue, FinalValue> : IteratorProtocol  {
  public typealias Element = PeriodicValue
  private var _implBox: Box<ChannelIteratorImpl<PeriodicValue, FinalValue>> // want to have reference to reference, because impl may actually be retained by some handler

  /// final value of the channel. Will be available as soon as the channel completes.
  public var finalValue: Fallible<FinalValue>? { return _implBox.value.finalValue }

  /// **internal use only** Designated initializer
  init(impl: ChannelIteratorImpl<PeriodicValue, FinalValue>) {
    _implBox = Box(impl)
  }

  /// fetches next value from the channel. Waits for the next value to appear. Returns nil when then channel completes
  public mutating func next() -> PeriodicValue? {
    if !isKnownUniquelyReferenced(&_implBox) {
      _implBox = Box(_implBox.value.clone())
    }
    return _implBox.value.next()
  }
}

/// **Internal use only**
private class Box<T> {
  let value: T
  init(_ value: T) {
    self.value = value
  }
}

/// **Internal use only**
class ChannelIteratorImpl<PeriodicValue, FinalValue>  {
  public typealias Element = PeriodicValue
  var finalValue: Fallible<FinalValue>? { assertAbstract() }

  init() { }

  public func next() -> PeriodicValue? {
    assertAbstract()
  }

  func clone() -> ChannelIteratorImpl<PeriodicValue, FinalValue> {
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

/// **internal use only** Wraps each block submitted to the channel to provide required memory management behavior
final public class ChannelHandler<T, U> {
  public typealias PeriodicValue = T
  public typealias SuccessValue = U
  public typealias Value = ChannelValue<PeriodicValue, SuccessValue>

  let executor: Executor
  let block: (Value) -> Void
  var owner: Channel<T, U>?

  /// Designated initializer of ChannelHandler
  public init(executor: Executor, block: @escaping (Value) -> Void, owner: Channel<T, U>) {
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
