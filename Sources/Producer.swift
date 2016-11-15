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

final public class Producer<PeriodicValue, FinalValue> : Channel<PeriodicValue, FinalValue>, MutableFinite {
  public typealias ImmutableFinite = Channel<PeriodicValue, FinalValue>

  typealias RegularState = RegularProducerState<PeriodicValue, FinalValue>
  typealias FinalState = FinalProducerState<PeriodicValue, FinalValue>
  private let _releasePool = ReleasePool()
  private var _container = makeThreadSafeContainer()
  private let _maxBufferSize: Int
  private let _bufferedPeriodics = QueueImpl<PeriodicValue>()
  private var _locking = makeLocking()

  override public var bufferSize: Int { return Int(_bufferedPeriodics.count) }
  override public var maxBufferSize: Int { return _maxBufferSize }

  override public var finalValue: Fallible<FinalValue>? { return (_container.head as? FinalState)?.final }

  override public convenience init() {
    self.init(bufferSize: 0)
  }
  
  public init(bufferSize: Int) {
    _maxBufferSize = bufferSize
  }

  /// **internal use only**
  override public func makeHandler(executor: Executor,
                                   block: @escaping (Value) -> Void) -> Handler? {
    let handler = Handler(executor: executor, block: block)
    _container.updateHead {
      switch $0 {
      case .none:
        return RegularState(handler: handler, next: nil)
      case let regularState as RegularState:
        return RegularState(handler: handler, next: regularState)
      case let finalState as FinalState:
        handler.handle(.final(finalState.final))
        return $0
      default:
        fatalError()
      }
    }

    executor.execute {
      self._locking.lock()
      var iterator = self._bufferedPeriodics.makeIterator()
      while let periodic_ = iterator.next() {
        block(.periodic(periodic_))
      }
      self._locking.unlock()
    }

    return handler
  }

  @discardableResult
  private func notify(_ value: Value, head: ProducerState<PeriodicValue, FinalValue>?) -> Bool {
    guard let regularState = head as? RegularState else { return false }
    var nextItem: RegularState? = regularState
    
    while let currentItem = nextItem {
      currentItem.handler?.handle(value)
      nextItem = currentItem.next
    }
    return true
  }

  public func apply(_ value: Value) {
    switch value {
    case let .periodic(periodic):
      self.send(periodic)
    case let .final(final):
      self.complete(with: final)
    }
  }

  private func _pushPeriodicToBuffer(_ periodic: PeriodicValue) {
    _bufferedPeriodics.push(periodic)
    if self.bufferSize > self.maxBufferSize {
      let _ = _bufferedPeriodics.pop()
    }
  }

  public func send(_ periodic: PeriodicValue) {

    if self.maxBufferSize > 0 {
      _locking.lock()
      _pushPeriodicToBuffer(periodic)
      _locking.unlock()
    }

    self.notify(.periodic(periodic), head: _container.head as! ProducerState<PeriodicValue, FinalValue>?)
  }

  public func send<S : Sequence>(_ periodics: S)
    where S.Iterator.Element == PeriodicValue {

      if self.maxBufferSize > 0 {
        _locking.lock()
        for periodic in periodics.suffix(self.maxBufferSize) {
          _pushPeriodicToBuffer(periodic)
        }
        _locking.unlock()
      }

      let localHead = _container.head
      for periodic in periodics {
        self.notify(.periodic(periodic), head: localHead as! ProducerState<PeriodicValue, FinalValue>?)
      }
  }
  
  @discardableResult
  public func tryComplete(with final: Fallible<FinalValue>) -> Bool {
    let (oldHead, newHead) = _container.updateHead {
      switch $0 {
      case .none:
        return FinalState(final: final)
      case is RegularState:
        return FinalState(final: final)
      case is FinalState:
        return $0
      default:
        fatalError()
      }
    }
    
    guard nil != newHead else { return false }
    
    return self.notify(.final(final), head: oldHead as! ProducerState<PeriodicValue, FinalValue>?)
  }

  public func insertToReleasePool(_ releasable: Releasable) {
    assert((releasable as? AnyObject) !== self) // Xcode 8 mistreats this. This code is valid
    if !self.isComplete {
      self._releasePool.insert(releasable)
    }
  }

  public func complete(with finite: ImmutableFinite) {
    let handler = finite.makeHandler(executor: .immediate) { [weak self] in
      self?.apply($0)
    }
    
    if let handler = handler {
      self.insertToReleasePool(handler)
    }
  }

  func notifyDrain(_ block: @escaping () -> Void) {
    if self.isComplete {
      block()
    } else {
      self._releasePool.notifyDrain(block)
    }
  }

  override public func makeIterator() -> Iterator {
    if self.maxBufferSize > 0 {
      _locking.lock()
      defer { _locking.unlock() }
    }
    let channelIteratorImpl = ProducerIteratorImpl<PeriodicValue, FinalValue>(channel: self, bufferedPeriodics: _bufferedPeriodics.clone())
    return ChannelIterator(impl: channelIteratorImpl)
  }
}

class ProducerState<T, U> {
  typealias Value = ChannelValue<T, U>
  typealias Handler = ChannelHandler<T, U>
  
  init() { }
}

final class RegularProducerState<T, U> : ProducerState<T, U> {
  weak var handler: Handler?
  let next: RegularProducerState<T, U>?
  
  init(handler: Handler, next: RegularProducerState<T, U>?) {
    self.handler = handler
    self.next = next
  }
}

final class FinalProducerState<T, U> : ProducerState<T, U> {
  let final: Fallible<U>
  
  init(final: Fallible<U>) {
    self.final = final
  }
}

public enum DerivedChannelBufferSize {
  case `default`
  case inherited
  case specific(Int)

  func bufferSize<T, U>(for parentChannel: Channel<T, U>) -> Int {
    switch self {
    case .default: return 0
    case .inherited: return parentChannel.maxBufferSize
    case let .specific(value): return value
    }
  }
}

class ProducerIteratorImpl<PeriodicValue, FinalValue> : ChannelIteratorImpl<PeriodicValue, FinalValue> {
  let _sema: DispatchSemaphore
  var _locking = makeLocking()
  let _bufferedPeriodics: QueueImpl<PeriodicValue>
  let _channel: Channel<PeriodicValue, FinalValue>
  var _handler: ChannelHandler<PeriodicValue, FinalValue>?
  override var finalValue: Fallible<FinalValue>? {
    _locking.lock()
    defer { _locking.unlock() }
    return _finalValue
  }
  var _finalValue: Fallible<FinalValue>?

  override init(channel: Channel<PeriodicValue, FinalValue>, bufferedPeriodics: QueueImpl<PeriodicValue>) {
    _channel = channel
    _bufferedPeriodics = bufferedPeriodics
    _sema = DispatchSemaphore(value: bufferedPeriodics.count)
    super.init(channel: channel, bufferedPeriodics: bufferedPeriodics)
    _handler = channel.makeHandler(executor: .immediate) { [weak self] (value) in
      self?.handle(value)
    }
  }

  override public func next() -> PeriodicValue? {
    _sema.wait()

    _locking.lock()
    defer { _locking.unlock() }

    return _bufferedPeriodics.pop()
  }

  override func clone() -> ChannelIteratorImpl<PeriodicValue, FinalValue> {
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
