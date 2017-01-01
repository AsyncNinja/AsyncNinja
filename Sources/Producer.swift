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

  fileprivate typealias RegularState = RegularProducerState<PeriodicValue, FinalValue>
  fileprivate typealias FinalState = FinalProducerState<PeriodicValue, FinalValue>
  private let _releasePool = ReleasePool()
  private var _container = makeThreadSafeContainer()
  private let _maxBufferSize: Int
  private let _bufferedPeriodics = QueueImpl<PeriodicValue>()
  private var _locking = makeLocking()

  override public var bufferSize: Int { return Int(_bufferedPeriodics.count) }
  override public var maxBufferSize: Int { return _maxBufferSize }

  override public var finalValue: Fallible<FinalValue>? { return (_container.head as? FinalState)?.final }

  override public convenience init() {
    self.init(bufferSize: AsyncNinjaConstants.defaultChannelBufferSize)
  }
  
  public init(bufferSize: Int) {
    _maxBufferSize = bufferSize
  }

  /// **internal use only**
  override public func makeHandler(executor: Executor,
                                   block: @escaping (Value) -> Void) -> Handler? {
    return self._makeHandler(executor: executor, avoidLocking: false, block: block)
  }

  fileprivate func _makeHandler(executor: Executor, avoidLocking: Bool,
                                block: @escaping (Value) -> Void) -> Handler? {
    if !avoidLocking {
      self._locking.lock()
    }

    var iterator = self._bufferedPeriodics.makeIterator()
    while let periodic_ = iterator.next() {
      executor.execute {
        block(.periodic(periodic_))
      }
    }

    let handler = Handler(executor: executor, block: block, owner: self)
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

    if !avoidLocking {
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
        periodics.suffix(self.maxBufferSize).forEach(_pushPeriodicToBuffer)
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
      case let regularState as RegularState:
        var enumeratedRegularState: RegularState? = regularState

        while let regularState = enumeratedRegularState {
          regularState.handler?.releaseOwner()
          enumeratedRegularState = regularState.next
        }

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

  override public func insertToReleasePool(_ releasable: Releasable) {
    // assert((releasable as? AnyObject) !== self) // Xcode 8 mistreats this. This code is valid
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
    _locking.lock()
    defer { _locking.unlock() }
    let channelIteratorImpl = ProducerIteratorImpl<PeriodicValue, FinalValue>(channel: self, bufferedPeriodics: _bufferedPeriodics.clone())
    return ChannelIterator(impl: channelIteratorImpl)
  }
}

/// Convenience factory of Channel. Encapsulates cancellation and producer creation.
public func channel<PeriodicValue, FinalValue>(
  executor: Executor = .primary,
  cancellationToken: CancellationToken? = nil,
  bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
  block: @escaping (_ sendPeriodic: @escaping (PeriodicValue) -> Void) throws -> FinalValue
  ) -> Channel<PeriodicValue, FinalValue> {

  let producer = Producer<PeriodicValue, FinalValue>(bufferSize: AsyncNinjaConstants.defaultChannelBufferSize)

  if let cancellationToken = cancellationToken {
    cancellationToken.notifyCancellation { [weak producer] in
      producer?.cancel()
    }
  }

  executor.execute { [weak producer] in
    let fallibleFinalValue = fallible { try block { producer?.send($0) } }
    producer?.complete(with: fallibleFinalValue)
  }

  return producer
}

/// Convenience contextual factory of Channel. Encapsulates cancellation and producer creation.
public func channel<U: ExecutionContext, PeriodicValue, FinalValue>(
  context: U,
  executor: Executor? = nil,
  cancellationToken: CancellationToken? = nil,
  bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
  block: @escaping (_ strongContext: U, _ sendPeriodic: @escaping (PeriodicValue) -> Void) throws -> FinalValue
  ) -> Channel<PeriodicValue, FinalValue> {

  let producer = Producer<PeriodicValue, FinalValue>(bufferSize: AsyncNinjaConstants.defaultChannelBufferSize)

  context.notifyDeinit { [weak producer] in
    producer?.cancelBecauseOfDeallocatedContext()
  }

  if let cancellationToken = cancellationToken {
    cancellationToken.notifyCancellation { [weak producer] in
      producer?.cancel()
    }
  }

  (executor ?? context.executor).execute { [weak context, weak producer] in
    guard nil != producer else { return }
    guard let context = context else {
      producer?.cancelBecauseOfDeallocatedContext()
      return
    }
    let fallibleFinalValue = fallible { try block(context) { producer?.send($0) } }
    producer?.complete(with: fallibleFinalValue)
  }

  return producer
}

fileprivate class ProducerState<T, U> {
  typealias Value = ChannelValue<T, U>
  typealias Handler = ChannelHandler<T, U>
  
  init() { }
}

fileprivate class RegularProducerState<T, U> : ProducerState<T, U> {
  weak var handler: Handler?
  let next: RegularProducerState<T, U>?
  
  init(handler: Handler, next: RegularProducerState<T, U>?) {
    self.handler = handler
    self.next = next
  }
}

fileprivate class FinalProducerState<T, U> : ProducerState<T, U> {
  let final: Fallible<U>

  init(final: Fallible<U>) {
    self.final = final
  }
}

/// Specifies strategy of selecting buffer size of channel derived from another channel, e.g through transformations
public enum DerivedChannelBufferSize {

  /// Specifies strategy to use as default value for arguments of methods
  case `default`

  /// Buffer size is defined by the buffer size of original channel
  case inherited

  /// Buffer size is defined by specified value
  case specific(Int)

  func bufferSize<T, U>(for parentChannel: Channel<T, U>) -> Int {
    switch self {
    case .default: return AsyncNinjaConstants.defaultChannelBufferSize
    case .inherited: return parentChannel.maxBufferSize
    case let .specific(value): return value
    }
  }
}

fileprivate class ProducerIteratorImpl<PeriodicValue, FinalValue> : ChannelIteratorImpl<PeriodicValue, FinalValue> {
  let _sema: DispatchSemaphore
  var _locking = makeLocking(isFair: true)
  let _bufferedPeriodics: QueueImpl<PeriodicValue>
  let _producer: Producer<PeriodicValue, FinalValue>
  var _handler: ChannelHandler<PeriodicValue, FinalValue>?
  override var finalValue: Fallible<FinalValue>? {
    _locking.lock()
    defer { _locking.unlock() }
    return _finalValue
  }
  var _finalValue: Fallible<FinalValue>?

  init(channel: Producer<PeriodicValue, FinalValue>, bufferedPeriodics: QueueImpl<PeriodicValue>) {
    _producer = channel
    _bufferedPeriodics = bufferedPeriodics
    _sema = DispatchSemaphore(value: 0)
    for _ in 0..<_bufferedPeriodics.count {
      _sema.signal()
    }
    super.init()
    _handler = channel._makeHandler(executor: .immediate, avoidLocking: true) { [weak self] (value) in
      self?.handle(value)
    }
  }

  override public func next() -> PeriodicValue? {
    _sema.wait()

    _locking.lock()
    defer { _locking.unlock() }

    if let periodic = _bufferedPeriodics.pop() {
      return periodic
    } else {
      _sema.signal()
      return nil
    }
  }

  override func clone() -> ChannelIteratorImpl<PeriodicValue, FinalValue> {
    return ProducerIteratorImpl(channel: _producer, bufferedPeriodics: _bufferedPeriodics.clone())
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
