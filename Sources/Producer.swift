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

/// Mutable subclass of channel
/// You can send periodics and complete producer manually
final public class Producer<Periodic, Success>: Channel<Periodic, Success>, MutableCompletable {
  public typealias ImmutableCompletable = Channel<Periodic, Success>

  private let _maxBufferSize: Int
  private let _bufferedPeriodics = Queue<Periodic>()
  private let _releasePool = ReleasePool(locking: PlaceholderLocking())
  private var _locking = makeLocking()
  private var _handlers = QueueOfWeakElements<Handler>()
  private var _completion: Fallible<Success>?

  /// amount of currently stored periodics
  override public var bufferSize: Int {
    _locking.lock()
    defer { _locking.unlock() }
    return Int(_bufferedPeriodics.count)
  }
  /// maximal amount of periodics store
  override public var maxBufferSize: Int { return _maxBufferSize }

  /// completion of `Producer`. Returns nil if channel is not complete yet
  override public var completion: Fallible<Success>? {
    _locking.lock()
    defer { _locking.unlock() }
    return _completion
  }

  /// convenience initializer of Producer. Initializes Producer with default buffer size
  override public convenience init() {
    self.init(bufferSize: AsyncNinjaConstants.defaultChannelBufferSize)
  }

  /// designated initializer of Producer. Initializes Producer with specified buffer size
  public init(bufferSize: Int) {
    _maxBufferSize = bufferSize
  }

  /// designated initializer of Producer. Initializes Producer with specified buffer size and values
  public init<S: Sequence>(bufferSize: Int, bufferedPeriodics: S) where S.Iterator.Element == Periodic {
    _maxBufferSize = bufferSize
    bufferedPeriodics.suffix(bufferSize).forEach(_bufferedPeriodics.push)
  }

  /// designated initializer of Producer. Initializes Producer with specified buffer size and values
  public init<C: Collection>(bufferedPeriodics: C) where C.Iterator.Element == Periodic, C.IndexDistance: Integer {
    _maxBufferSize = Int(bufferedPeriodics.count.toIntMax())
    bufferedPeriodics.forEach(_bufferedPeriodics.push)
  }

  /// **internal use only**
  override public func makeHandler(executor: Executor,
                                   block: @escaping (Value) -> Void
    ) -> Handler? {
    return self._makeHandler(executor: executor,
                             avoidLocking: false,
                             block: block)
  }

  fileprivate func _makeHandler(executor: Executor, avoidLocking: Bool,
                                block: @escaping (Value) -> Void
    ) -> Handler? {
    if !avoidLocking {
      self._locking.lock()
    }

    for periodic_ in self._bufferedPeriodics {
      executor.execute {
        block(.periodic(periodic_))
      }
    }

    let handler = Handler(executor: executor, block: block, owner: self)
    if let completion = _completion {
      handler.handle(.completion(completion))
    } else {
      _handlers.push(handler)
    }

    if !avoidLocking {
      self._locking.unlock()
    }

    return handler
  }

  /// Applies specified ChannelValue to the Producer
  /// Value will not be applied for completed Producer
  public func apply(_ value: Value) {
    switch value {
    case let .periodic(periodic):
      self.send(periodic)
    case let .completion(completion):
      self.complete(with: completion)
    }
  }

  private func _pushPeriodicToBuffer(_ periodic: Periodic) {
    _bufferedPeriodics.push(periodic)
    if _bufferedPeriodics.count > self.maxBufferSize {
      let _ = _bufferedPeriodics.pop()
    }
  }

  /// Sends specified Periodic to the Producer
  /// Value will not be sent for completed Producer
  public func send(_ periodic: Periodic) {

    _locking.lock()
    defer { _locking.unlock() }
    guard case .none = _completion
      else { return }

    if self.maxBufferSize > 0 {
      _pushPeriodicToBuffer(periodic)
    }

    let value = Value.periodic(periodic)
    _handlers.forEach { $0.handle(value) }
  }

  /// Sends specified sequence of Periodic to the Producer
  /// Values will not be sent for completed Producer
  public func send<S: Sequence>(_ periodics: S)
    where S.Iterator.Element == Periodic {

      _locking.lock()
      defer { _locking.unlock() }
      guard case .none = _completion
        else { return }

      if self.maxBufferSize > 0 {
        periodics.suffix(self.maxBufferSize).forEach(_pushPeriodicToBuffer)
      }

      _handlers.forEach {
        for periodic in periodics {
          $0.handle(.periodic(periodic))
        }
      }
  }

  /// Tries to complete the Producer
  ///
  /// - Parameter completion: value to complete Producer with
  /// - Returns: true if Producer was completed with this call,
  ///   false if it was completed before
  @discardableResult
  public func tryComplete(with completion: Fallible<Success>) -> Bool {
    _locking.lock()
    defer { _locking.unlock() }

    guard case .none = _completion
      else { return false }

    _completion = completion
    _handlers.forEach(andReset: true) { handler in
      handler.handle(.completion(completion))
      handler.releaseOwner()
    }

    return true
  }

  /// Completes the channel with a competion of specified Future or Channel
  public func complete(with completable: ImmutableCompletable) {
    let handler = completable.makeHandler(executor: .immediate) { [weak self] in
      self?.apply($0)
    }

    self.insertHandlerToReleasePool(handler)
  }

  /// **internal use only** Inserts releasable to an internal release pool
  /// that will be drained on completion
  override public func insertToReleasePool(_ releasable: Releasable) {
    // assert((releasable as? AnyObject) !== self) // Xcode 8 mistreats this. This code is valid
    _locking.lock()
    defer { _locking.unlock() }
    if case .none = _completion {
      _releasePool.insert(releasable)
    }
  }

  /// **internal use only**
  func notifyDrain(_ block: @escaping () -> Void) {
    _locking.lock()
    defer { _locking.unlock() }
    if case .none = _completion {
      _releasePool.notifyDrain(block)
    }
  }

  /// Makes an iterator that allows synchronous iteration over periodic values of the channel
  override public func makeIterator() -> Iterator {
    _locking.lock()
    defer { _locking.unlock() }
    let channelIteratorImpl = ProducerIteratorImpl<Periodic, Success>(channel: self, bufferedPeriodics: Queue())
    return ChannelIterator(impl: channelIteratorImpl)
  }
}

// MARK: - Constructors

/// Convenience constructor of Channel. Encapsulates cancellation and producer creation.
public func channel<Periodic, Success>(
  executor: Executor = .primary,
  cancellationToken: CancellationToken? = nil,
  bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
  block: @escaping (_ sendPeriodic: @escaping (Periodic) -> Void) throws -> Success
  ) -> Channel<Periodic, Success> {

  let producer = Producer<Periodic, Success>(bufferSize: AsyncNinjaConstants.defaultChannelBufferSize)

  cancellationToken?.add(cancellable: producer)

  executor.execute { [weak producer] in
    let fallibleCompletion = fallible { try block { producer?.send($0) } }
    producer?.complete(with: fallibleCompletion)
  }

  return producer
}

/// Convenience contextual constructor of Channel. Encapsulates cancellation and producer creation.
public func channel<U: ExecutionContext, Periodic, Success>(
  context: U,
  executor: Executor? = nil,
  cancellationToken: CancellationToken? = nil,
  bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
  block: @escaping (_ strongContext: U, _ sendPeriodic: @escaping (Periodic) -> Void) throws -> Success
  ) -> Channel<Periodic, Success> {

  let producer = Producer<Periodic, Success>(bufferSize: AsyncNinjaConstants.defaultChannelBufferSize)

  context.addDependent(completable: producer)
  cancellationToken?.add(cancellable: producer)

  (executor ?? context.executor).execute { [weak context, weak producer] in
    guard nil != producer else { return }
    guard let context = context else {
      producer?.cancelBecauseOfDeallocatedContext()
      return
    }
    let fallibleCompletable = fallible { try block(context) { producer?.send($0) } }
    producer?.complete(with: fallibleCompletable)
  }

  return producer
}

/// Convenience function constructs completed Channel with specified periodics and completion
public func channel<C: Collection, Success>(periodics: C, completion: Fallible<Success>
  ) -> Channel<C.Iterator.Element, Success>
  where C.IndexDistance: Integer {
    let producer = Producer<C.Iterator.Element, Success>(bufferedPeriodics: periodics)
    producer.complete(with: completion)
    return producer
}

/// Convenience function constructs succeded Channel with specified periodics and success
public func channel<C: Collection, Success>(periodics: C, success: Success
  ) -> Channel<C.Iterator.Element, Success>
  where C.IndexDistance: Integer {
    return channel(periodics: periodics, completion: .success(success))
}

/// Convenience function constructs failed Channel with specified periodics and failure
public func channel<C: Collection, Success>(periodics: C, failure: Swift.Error
  ) -> Channel<C.Iterator.Element, Success>
  where C.IndexDistance: Integer {
    return channel(periodics: periodics, completion: .failure(failure))
}

/// Specifies strategy of selecting buffer size of channel derived
/// from another channel, e.g through transformations
public enum DerivedChannelBufferSize {

  /// Specifies strategy to use as default value for arguments of methods
  case `default`

  /// Buffer size is defined by the buffer size of original channel
  case inherited

  /// Buffer size is defined by specified value
  case specific(Int)

  /// **internal use only**
  func bufferSize<T, U>(_ parentChannel: Channel<T, U>) -> Int {
    switch self {
    case .default: return AsyncNinjaConstants.defaultChannelBufferSize
    case .inherited: return parentChannel.maxBufferSize
    case let .specific(value): return value
    }
  }

  /// **internal use only**
  func bufferSize<PeriodicA, SuccessA, PeriodicB, SuccessB>(
    _ parentChannelA: Channel<PeriodicA, SuccessA>,
    _ parentChannelB: Channel<PeriodicB, SuccessB>
    ) -> Int {
    switch self {
    case .default: return AsyncNinjaConstants.defaultChannelBufferSize
    case .inherited: return max(parentChannelA.maxBufferSize, parentChannelB.maxBufferSize)
    case let .specific(value): return value
    }
  }
}

// MARK: - Iterators
fileprivate class ProducerIteratorImpl<Periodic, Success>: ChannelIteratorImpl<Periodic, Success> {
  let _sema: DispatchSemaphore
  var _locking = makeLocking(isFair: true)
  let _bufferedPeriodics: Queue<Periodic>
  let _producer: Producer<Periodic, Success>
  var _handler: ChannelHandler<Periodic, Success>?
  override var completion: Fallible<Success>? {
    _locking.lock()
    defer { _locking.unlock() }
    return _completion
  }
  var _completion: Fallible<Success>?

  init(channel: Producer<Periodic, Success>, bufferedPeriodics: Queue<Periodic>) {
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

  override public func next() -> Periodic? {
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

  override func clone() -> ChannelIteratorImpl<Periodic, Success> {
    return ProducerIteratorImpl(channel: _producer, bufferedPeriodics: _bufferedPeriodics.clone())
  }

  func handle(_ value: ChannelValue<Periodic, Success>) {
    _locking.lock()
    defer { _locking.unlock() }

    if case .some = _completion { return }

    switch value {
    case let .periodic(periodic):
      _bufferedPeriodics.push(periodic)
    case let .completion(completion):
      _completion = completion
    }
    
    _sema.signal()
  }
}
