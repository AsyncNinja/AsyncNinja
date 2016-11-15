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
    /* abstract */
    fatalError()
  }
  
  public func onValue<U: ExecutionContext>(context: U, executor: Executor? = nil,
                      block: @escaping (U, Value) -> Void) {
    let handler = self.makeHandler(executor: executor ?? context.executor) { [weak context] (value) in
      guard let context = context else { return }
      block(context, value)
    }
    
    if let handler = handler {
      context.releaseOnDeinit(handler)
    }
  }

  func onPeriodic<U: ExecutionContext>(context: U, executor: Executor? = nil,
                  block: @escaping (U, PeriodicValue) -> Void) {
    self.onValue(context: context) { (context, value) in
      switch value {
      case let .periodic(periodic):
        block(context, periodic)
      case .final: nop()
      }
    }
  }

  public func makeIterator() -> Iterator {
    /* abstract */
    fatalError()
  }
}

public struct ChannelIterator<PeriodicValue, FinalValue> : IteratorProtocol  {
  public typealias Element = PeriodicValue
  var _impl: ChannelIteratorImpl<PeriodicValue, FinalValue>
  public var finalValue: Fallible<FinalValue>? { return _impl.finalValue }

  init(impl: ChannelIteratorImpl<PeriodicValue, FinalValue>) {
    _impl = impl
  }

  public mutating func next() -> PeriodicValue? {
    if !isKnownUniquelyReferenced(&_impl) {
      _impl = _impl.clone()
    }
    return _impl.next()
  }
}

class ChannelIteratorImpl<PeriodicValue, FinalValue>  {
  public typealias Element = PeriodicValue
  let _sema: DispatchSemaphore
  var _locking = makeLocking()
  let _bufferedPeriodics: QueueImpl<PeriodicValue>
  let _channel: Channel<PeriodicValue, FinalValue>
  var _handler: ChannelHandler<PeriodicValue, FinalValue>?
  var finalValue: Fallible<FinalValue>? {
    _locking.lock()
    defer { _locking.unlock() }
    return _finalValue
  }
  var _finalValue: Fallible<FinalValue>?

  init(channel: Channel<PeriodicValue, FinalValue>, bufferedPeriodics: QueueImpl<PeriodicValue>) {
    _channel = channel
    _bufferedPeriodics = bufferedPeriodics
    _sema = DispatchSemaphore(value: bufferedPeriodics.count)
    _handler = channel.makeHandler(executor: .immediate) { [weak self] (value) in
      self?.handle(value)
    }
  }

  public func next() -> PeriodicValue? {
    _sema.wait()

    _locking.lock()
    defer { _locking.unlock() }

    return _bufferedPeriodics.pop()
  }

  func clone() -> ChannelIteratorImpl<PeriodicValue, FinalValue> {
    return ChannelIteratorImpl(channel: _channel, bufferedPeriodics: _bufferedPeriodics.clone())
  }

  func handle(_ value: ChannelValue<PeriodicValue, FinalValue>) {
    _locking.lock()
    defer { _locking.unlock() }

    if let _ = _finalValue { return }

    switch value {
    case let .periodic(periodic):
      _bufferedPeriodics.push(periodic)
    case let .final(final):
      _finalValue = final
    }

    _sema.signal()
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

  public init(executor: Executor, block: @escaping (Value) -> Void) {
    self.executor = executor
    self.block = block
  }

  func handle(_ value: Value) {
    let block = self.block
    self.executor.execute { block(value) }
  }
}
