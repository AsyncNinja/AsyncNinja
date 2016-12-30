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

public class Channel<PeriodicValue, FinalValue> : Finite {
  public typealias Value = ChannelValue<PeriodicValue, FinalValue>
  public typealias Handler = ChannelHandler<PeriodicValue, FinalValue>
  public typealias PeriodicHandler = Handler
  public typealias FinalHandler = Handler
  public typealias Iterator = ChannelIterator<PeriodicValue, FinalValue>

  public var finalValue: Fallible<FinalValue>? {
    /* abstact */
    fatalError()
  }
  public var bufferSize: Int {
    /* abstact */
    fatalError()
  }
  public var maxBufferSize: Int {
    /* abstact */
    fatalError()
  }

  init() { }

  final public func makeFinalHandler(executor: Executor,
                                     block: @escaping (Fallible<FinalValue>) -> Void) -> Handler? {
    return self.makeHandler(executor: executor) {
      if case .final(let value) = $0 { block(value) }
    }
  }

  final public func makePeriodicHandler(executor: Executor,
                                          block: @escaping (PeriodicValue) -> Void) -> Handler? {
    return self.makeHandler(executor: executor) {
      if case .periodic(let value) = $0 { block(value) }
    }
  }
  public func makeHandler(executor: Executor,
                          block: @escaping (Value) -> Void) -> Handler? {
    assertAbstract()
  }
  
  public func makeIterator() -> Iterator {
    assertAbstract()
  }
  
  /// **Internal use only**.
  public func insertToReleasePool(_ releasable: Releasable) {
    assertAbstract()
  }
}

public extension Channel {
  func onValue(executor: Executor = .primary, block: @escaping (Value) -> Void) {
    let handler = self.makeHandler(executor: executor, block: block)
    
    if let handler = handler {
      self.insertToReleasePool(handler)
    }
  }

  func onValue<U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    block: @escaping (U, Value) -> Void) {
    let handler = self.makeHandler(executor: executor ?? context.executor) { [weak context] (value) in
      guard let context = context else { return }
      block(context, value)
    }

    if let handler = handler {
      context.releaseOnDeinit(handler)
    }
  }
  
  func onPeriodic(executor: Executor = .primary, block: @escaping (PeriodicValue) -> Void) {
    self.onValue(executor: executor) { (value) in
      switch value {
      case let .periodic(periodic):
        block(periodic)
      case .final: nop()
      }
    }
  }

  func onPeriodic<U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    block: @escaping (U, PeriodicValue) -> Void) {
    self.onValue(context: context, executor: executor) { (context, value) in
      switch value {
      case let .periodic(periodic):
        block(context, periodic)
      case .final: nop()
      }
    }
  }

  func extractAll<U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    block: @escaping (U, [PeriodicValue], Fallible<FinalValue>) -> Void) {
    var locking = makeLocking()
    var periodics = [PeriodicValue]()
    let handler = self.makeHandler(executor: executor ?? context.executor) { [weak context] (value) in
      guard let context = context else { return }
      switch value {
      case let .periodic(periodic):
        locking.lock()
        defer { locking.unlock() }
        periodics.append(periodic)
      case let .final(final):
        block(context, periodics, final)
      }
    }

    if let handler = handler {
      context.releaseOnDeinit(handler)
    }
  }

  func waitForAll() -> (periodics: [PeriodicValue], final: Fallible<FinalValue>) {
    var periodics = [PeriodicValue]()
    var iterator = self.makeIterator()
    while let periodic = iterator.next() {
      periodics.append(periodic)
    }
    return (periodics, iterator.finalValue!)
  }
}

public struct ChannelIterator<PeriodicValue, FinalValue> : IteratorProtocol  {
  public typealias Element = PeriodicValue
  private var _implBox: Box<ChannelIteratorImpl<PeriodicValue, FinalValue>> // want to have reference to reference, because impl may actually be retained by some handler
  public var finalValue: Fallible<FinalValue>? { return _implBox.value.finalValue }

  init(impl: ChannelIteratorImpl<PeriodicValue, FinalValue>) {
    _implBox = Box(impl)
  }

  public mutating func next() -> PeriodicValue? {
    if !isKnownUniquelyReferenced(&_implBox) {
      _implBox = Box(_implBox.value.clone())
    }
    return _implBox.value.next()
  }
}

private class Box<T> {
  let value: T
  init(_ value: T) {
    self.value = value
  }
}

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

public enum ChannelValue<T, U> {
  public typealias PeriodicValue = T
  public typealias SuccessValue = U

  case periodic(PeriodicValue)
  case final(Fallible<SuccessValue>)
}

/// **internal use only**
final public class ChannelHandler<T, U> {
  public typealias PeriodicValue = T
  public typealias SuccessValue = U
  public typealias Value = ChannelValue<PeriodicValue, SuccessValue>

  let executor: Executor
  let block: (Value) -> Void
  let owner: Channel<T, U>

  public init(executor: Executor, block: @escaping (Value) -> Void, owner: Channel<T, U>) {
    self.executor = executor
    self.block = block
    self.owner = owner
  }

  func handle(_ value: Value) {
    let block = self.block
    self.executor.execute { block(value) }
  }
}
