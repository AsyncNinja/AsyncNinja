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

public typealias Updatable<T> = Producer<T, Void>
public typealias UpdatableProperty<T> = ProducerProxy<T, Void>

final public class Producer<Update, Success>: BaseProducer<Update, Success>, Completable {
  /// convenience initializer of Producer. Initializes Producer with default buffer size
  public init() {
    super.init(bufferSize: AsyncNinjaConstants.defaultChannelBufferSize)
  }
  
  /// designated initializer of Producer. Initializes Producer with specified buffer size
  override public init(bufferSize: Int) {
    super.init(bufferSize: bufferSize)
  }
  
  /// designated initializer of Producer. Initializes Producer with specified buffer size and values
  public init<S: Sequence>(bufferSize: Int, bufferedUpdates: S) where S.Iterator.Element == Update {
    super.init(bufferSize: bufferSize)
    bufferedUpdates.suffix(bufferSize).forEach(_bufferedUpdates.push)
  }
  
  /// designated initializer of Producer. Initializes Producer with specified buffer size and values
  public init<C: Collection>(bufferedUpdates: C) where C.Iterator.Element == Update, C.IndexDistance: Integer {
    super.init(bufferSize: Int(bufferedUpdates.count.toIntMax()))
    bufferedUpdates.forEach(_bufferedUpdates.push)
  }
}

/// Mutable subclass of channel
/// You can update and complete producer manually
/// **internal use only**
public class BaseProducer<Update, Success>: Channel<Update, Success>, BaseCompletable {
  public typealias CompletingType = Channel<Update, Success>

  private let _maxBufferSize: Int
  fileprivate let _bufferedUpdates = Queue<Update>()
  private let _releasePool = ReleasePool(locking: PlaceholderLocking())
  private var _locking = makeLocking()
  private var _handlers = QueueOfWeakElements<Handler>()
  private var _completion: Fallible<Success>?

  /// amount of currently stored updates
  override public var bufferSize: Int {
    _locking.lock()
    defer { _locking.unlock() }
    return Int(_bufferedUpdates.count)
  }
  /// maximal amount of updates store
  override public var maxBufferSize: Int { return _maxBufferSize }

  /// completion of `Producer`. Returns nil if channel is not complete yet
  override public var completion: Fallible<Success>? {
    _locking.lock()
    defer { _locking.unlock() }
    return _completion
  }

  /// designated initializer of Producer. Initializes Producer with specified buffer size
  init(bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize) {
    _maxBufferSize = bufferSize
  }

  /// **internal use only**
  override public func makeHandler(
    executor: Executor,
    _ block: @escaping (Event) -> Void
    ) -> Handler? {
    return _makeHandler(executor: executor, avoidLocking: false, block)
  }

  fileprivate func _makeHandler(
    executor: Executor, avoidLocking: Bool,
    _ block: @escaping (Event) -> Void
    ) -> Handler? {
    if !avoidLocking {
      _locking.lock()
    }
    
    for update_ in _bufferedUpdates {
      executor.execute {
        block(.update(update_))
      }
    }
    
    let handler = Handler(executor: executor, block: block, owner: self)
    if let completion = _completion {
      handler.handle(.completion(completion))
    } else {
      _handlers.push(handler)
    }
    
    if !avoidLocking {
      _locking.unlock()
    }
    
    return handler
  }

  /// Applies specified ChannelValue to the Producer
  /// Value will not be applied for completed Producer
    public func apply(_ event: Event) {
    switch event {
    case let .update(update):
      self.update(update)
    case let .completion(completion):
      self.complete(with: completion)
    }
  }

  private func _pushUpdateToBuffer(_ update: Update) {
    _bufferedUpdates.push(update)
    if _bufferedUpdates.count > self.maxBufferSize {
      let _ = _bufferedUpdates.pop()
    }
  }

  /// Sends specified Update to the Producer
  /// Value will not be sent for completed Producer
  public func update(_ update: Update) {

    _locking.lock()
    defer { _locking.unlock() }
    guard case .none = _completion
      else { return }

    if self.maxBufferSize > 0 {
      _pushUpdateToBuffer(update)
    }

    let event = Event.update(update)
    _handlers.forEach { $0.handle(event) }
  }

  /// Sends specified sequence of Update to the Producer
  /// Values will not be sent for completed Producer
  public func update<S: Sequence>(_ updates: S)
    where S.Iterator.Element == Update {

      _locking.lock()
      defer { _locking.unlock() }
      guard case .none = _completion
        else { return }

      if self.maxBufferSize > 0 {
        updates.suffix(self.maxBufferSize).forEach(_pushUpdateToBuffer)
      }

      _handlers.forEach {
        for update in updates {
          $0.handle(.update(update))
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
  public func complete(with completable: CompletingType) {
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

  /// Makes an iterator that allows synchronous iteration over update values of the channel
  override public func makeIterator() -> Iterator {
    _locking.lock()
    defer { _locking.unlock() }
    let channelIteratorImpl = ProducerIteratorImpl<Update, Success>(channel: self, bufferedUpdates: Queue())
    return ChannelIterator(impl: channelIteratorImpl)
  }
}

// MARK: - Constructors

/// Convenience constructor of Channel. Encapsulates cancellation and producer creation.
public func channel<Update, Success>(
  executor: Executor = .primary,
  cancellationToken: CancellationToken? = nil,
  bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
  block: @escaping (_ update: @escaping (Update) -> Void) throws -> Success
  ) -> Channel<Update, Success> {

  let producer = Producer<Update, Success>(bufferSize: AsyncNinjaConstants.defaultChannelBufferSize)

  cancellationToken?.add(cancellable: producer)

  executor.execute { [weak producer] in
    let fallibleCompletion = fallible { try block { producer?.update($0) } }
    producer?.complete(with: fallibleCompletion)
  }

  return producer
}

/// Convenience contextual constructor of Channel. Encapsulates cancellation and producer creation.
public func channel<U: ExecutionContext, Update, Success>(
  context: U,
  executor: Executor? = nil,
  cancellationToken: CancellationToken? = nil,
  bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
  block: @escaping (_ strongContext: U, _ update: @escaping (Update) -> Void) throws -> Success
  ) -> Channel<Update, Success> {

  let producer = Producer<Update, Success>(bufferSize: AsyncNinjaConstants.defaultChannelBufferSize)

  context.addDependent(completable: producer)
  cancellationToken?.add(cancellable: producer)

  (executor ?? context.executor).execute { [weak context, weak producer] in
    guard nil != producer else { return }
    guard let context = context else {
      producer?.cancelBecauseOfDeallocatedContext()
      return
    }
    let fallibleCompleting = fallible { try block(context) { producer?.update($0) } }
    producer?.complete(with: fallibleCompleting)
  }

  return producer
}

/// Convenience function constructs completed Channel with specified updates and completion
public func channel<C: Collection, Success>(updates: C, completion: Fallible<Success>
  ) -> Channel<C.Iterator.Element, Success>
  where C.IndexDistance: Integer {
    let producer = Producer<C.Iterator.Element, Success>(bufferedUpdates: updates)
    producer.complete(with: completion)
    return producer
}

/// Convenience function constructs succeded Channel with specified updates and success
public func channel<C: Collection, Success>(updates: C, success: Success
  ) -> Channel<C.Iterator.Element, Success>
  where C.IndexDistance: Integer {
    return channel(updates: updates, completion: .success(success))
}

/// Convenience function constructs failed Channel with specified updates and failure
public func channel<C: Collection, Success>(updates: C, failure: Swift.Error
  ) -> Channel<C.Iterator.Element, Success>
  where C.IndexDistance: Integer {
    return channel(updates: updates, completion: .failure(failure))
}

/// Convenience shortcuts for making completed channel
public extension Channel {

  /// Makes completed channel
  static func completed(_ completion: Fallible<Success>) -> Channel<Update, Success> {
    return channel(updates: [], completion: completion)
  }

  /// Makes succeeded channel
  static func succeeded(_ success: Success) -> Channel<Update, Success> {
    return .completed(.success(success))
  }

  /// Makes succeeded channel
  static func just(_ success: Success) -> Channel<Update, Success> {
    return .completed(.success(success))
  }

  /// Makes failed channel
  static func failed(_ failure: Swift.Error) -> Channel<Update, Success> {
    return .completed(.failure(failure))
  }

  /// Makes cancelled (failed with AsyncNinjaError.cancelled) channel
  static var cancelled: Channel<Update, Success> {
    return .failed(AsyncNinjaError.cancelled)
  }
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
  func bufferSize<UpdateA, SuccessA, UpdateB, SuccessB>(
    _ parentChannelA: Channel<UpdateA, SuccessA>,
    _ parentChannelB: Channel<UpdateB, SuccessB>
    ) -> Int {
    switch self {
    case .default: return AsyncNinjaConstants.defaultChannelBufferSize
    case .inherited: return max(parentChannelA.maxBufferSize, parentChannelB.maxBufferSize)
    case let .specific(value): return value
    }
  }
}

// MARK: - ProducerProxy

public class ProducerProxy<Update, Success>: BaseProducer<Update, Success> {
  private let _updateHandler: (ProducerProxy<Update, Success>, Event) -> Void
  private let _updateExecutor: Executor
  
  /// designated initializer of Producer. Initializes Producer with specified buffer size
  init(bufferSize: Int, updateExecutor: Executor, updateHandler: @escaping (ProducerProxy<Update, Success>, Event) -> Void) {
    _updateHandler = updateHandler
    _updateExecutor = updateExecutor
    super.init(bufferSize: bufferSize)
  }
  
  func updateWithoutHandling(_ update: Update) {
    super.update(update)
  }

  @discardableResult
  func tryCompleteWithoutHandling(with completion: Fallible<Success>) -> Bool {
    return super.tryComplete(with: completion)
  }

  override public func update(_ update: Update) {
    _updateExecutor.execute {
      self._updateHandler(self, .update(update))
    }
  }
  
  override public func tryComplete(with completion: Fallible<Success>) -> Bool {
    _updateExecutor.execute {
      self._updateHandler(self, .completion(completion))
    }
    return true
  }
}

// MARK: - Iterators
fileprivate class ProducerIteratorImpl<Update, Success>: ChannelIteratorImpl<Update, Success> {
  let _sema: DispatchSemaphore
  var _locking = makeLocking(isFair: true)
  let _bufferedUpdates: Queue<Update>
  let _producer: BaseProducer<Update, Success>
  var _handler: ChannelHandler<Update, Success>?
  override var completion: Fallible<Success>? {
    _locking.lock()
    defer { _locking.unlock() }
    return _completion
  }
  var _completion: Fallible<Success>?

  init(channel: BaseProducer<Update, Success>, bufferedUpdates: Queue<Update>) {
    _producer = channel
    _bufferedUpdates = bufferedUpdates
    _sema = DispatchSemaphore(value: 0)
    for _ in 0..<_bufferedUpdates.count {
      _sema.signal()
    }
    super.init()
    _handler = channel._makeHandler(executor: .immediate, avoidLocking: true) { [weak self] (event) in
      self?.handle(event)
    }
  }

  override public func next() -> Update? {
    _sema.wait()

    _locking.lock()
    defer { _locking.unlock() }

    if let update = _bufferedUpdates.pop() {
      return update
    } else {
      _sema.signal()
      return nil
    }
  }

  override func clone() -> ChannelIteratorImpl<Update, Success> {
    return ProducerIteratorImpl(channel: _producer, bufferedUpdates: _bufferedUpdates.clone())
  }

  func handle(_ value: ChannelEvent<Update, Success>) {
    _locking.lock()
    defer { _locking.unlock() }

    if case .some = _completion { return }

    switch value {
    case let .update(update):
      _bufferedUpdates.push(update)
    case let .completion(completion):
      _completion = completion
    }
    
    _sema.signal()
  }
}
