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
/// You can update and complete producer manually
/// **internal use only**
public class BaseProducer<Update, Success>: Channel<Update, Success>, EventsDestination {
  private let _maxBufferSize: Int
  let _bufferedUpdates = Queue<Update>()
  private let _releasePool = ReleasePool(locking: PlaceholderLocking())
  var _locking = makeLocking()
  private var _handlers = QueueOfWeakElements<ProducerHandler<Update, Success>>()
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
    _ block: @escaping (_ event: ChannelEvent<Update, Success>, _ originalExecutor: Executor) -> Void
    ) -> AnyObject?
  {
    return _locking.locker {
      return _makeHandler(executor: executor, block)
    }
  }
  
  fileprivate func _makeHandler(
    executor: Executor,
    _ block: @escaping (_ event: ChannelEvent<Update, Success>, _ originalExecutor: Executor) -> Void
    ) -> ProducerHandler<Update, Success>?
  {
    let handler = ProducerHandler(executor: executor, bufferedUpdates: _bufferedUpdates.clone(), owner: self, block: block)
    if let completion = _completion {
      handler.handle(.completion(completion), from: nil)
      return nil
    } else {
      _handlers.push(handler)
    }
    return handler
  }
  
  func _pushUpdateToBuffer(_ update: Update) {
    _bufferedUpdates.push(update)
    if _bufferedUpdates.count > self.maxBufferSize {
      let _ = _bufferedUpdates.pop()
    }
  }
  
  /// Sends specified Update to the Producer
  /// Value will not be sent for completed Producer
  ///
  /// - Parameter update: value to update with
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  public func tryUpdate(_ update: Update, from originalExecutor: Executor?) -> Bool {
    _locking.lock()
    guard case .none = _completion
      else {
        _locking.unlock()
        return false
    }
    
    if self.maxBufferSize > 0 {
      _pushUpdateToBuffer(update)
    }
    
    let event = Event.update(update)
    let handlers = _handlers
    _locking.unlock()
    handlers.forEach { $0.handle(event, from: originalExecutor) }
    return true
  }
  
  /// Sends specified sequence of Update to the Producer
  /// Values will not be sent for completed Producer
  ///
  /// - Parameter updates: values to update with
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  public func update<S: Sequence>(_ updates: S,
                     from originalExecutor: Executor? = nil)
    where S.Iterator.Element == Update {
      
      _locking.lock()
      guard case .none = _completion
        else {
          _locking.unlock()
          return
      }
      
      if self.maxBufferSize > 0 {
        updates.suffix(self.maxBufferSize).forEach(_pushUpdateToBuffer)
      }
      
      let handlers = _handlers
      _locking.unlock()
      
      handlers.forEach {
        for update in updates {
          $0.handle(.update(update), from: originalExecutor)
        }
      }
  }
  
  /// Tries to complete the Producer
  ///
  /// - Parameter completion: value to complete Producer with
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  /// - Returns: true if Producer was completed with this call,
  ///   false if it was completed before
  @discardableResult
  public func tryComplete(_ completion: Fallible<Success>,
                          from originalExecutor: Executor? = nil) -> Bool {
    _locking.lock()
    
    guard case .none = _completion
      else {
        _locking.unlock()
        return false
    }
    
    _completion = completion
    let handlers = _handlers
    _locking.unlock()
    
    handlers.forEach(andReset: true) { handler in
      handler.handle(.completion(completion), from: originalExecutor)
      handler.releaseOwner()
    }
    
    return true
  }
  
  /// Completes the channel with a competion of specified Future or Channel
  public func complete<T: Completing>(with completable: T) where T.Success == Success {
    let handler = completable.makeCompletionHandler(executor: .immediate) {
      [weak self] (completion, originalExecutor) in
      self?.complete(completion, from: originalExecutor)
    }
    
    self._asyncNinja_retainHandlerUntilFinalization(handler)
  }
  
  /// **internal use only** Inserts releasable to an internal release pool
  /// that will be drained on completion
  override public func _asyncNinja_retainUntilFinalization(_ releasable: Releasable) {
    // assert((releasable as? AnyObject) !== self) // Xcode 8 mistreats this. This code is valid
    _locking.lock()
    defer { _locking.unlock() }
    if case .none = _completion {
      _releasePool.insert(releasable)
    }
  }
  
  /// **internal use only** Inserts releasable to an internal release pool
  /// that will be drained on completion
  override public func _asyncNinja_notifyFinalization(_ block: @escaping () -> Void) {
    _locking.lock()
    defer { _locking.unlock() }
    if case .none = _completion {
      _releasePool.notifyDrain(block)
    } else {
      block()
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
    let channelIteratorImpl = ProducerIteratorImpl<Update, Success>(channel: self, bufferedUpdates: Queue())
    _locking.unlock()
    return ChannelIterator(impl: channelIteratorImpl)
  }
}

// MARK: - Iterators
fileprivate class ProducerIteratorImpl<Update, Success>: ChannelIteratorImpl<Update, Success> {
  let _sema: DispatchSemaphore
  var _locking = makeLocking(isFair: true)
  let _bufferedUpdates: Queue<Update>
  let _producer: BaseProducer<Update, Success>
  var _handler: ProducerHandler<Update, Success>?
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
    _handler = channel._makeHandler(executor: .immediate) {
      [weak self] (event, originalExecutor) in
      self?.handle(event, from: originalExecutor)
    }
  }
  
  override public func next() -> Update? {
    _sema.wait()
    
    _locking.lock()
    let update = _bufferedUpdates.pop()
    _locking.unlock()
    
    if let update = update {
      return update
    } else {
      _sema.signal()
      return nil
    }
  }
  
  override func clone() -> ChannelIteratorImpl<Update, Success> {
    return ProducerIteratorImpl(channel: _producer, bufferedUpdates: _bufferedUpdates.clone())
  }
  
  func handle(_ value: ChannelEvent<Update, Success>,
              from originalExecutor: Executor?) {
    _locking.lock()
    
    if case .some = _completion {
      _locking.unlock()
      return
    }
    
    switch value {
    case let .update(update):
      _bufferedUpdates.push(update)
    case let .completion(completion):
      _completion = completion
    }
    _locking.unlock()
    
    _sema.signal()
  }
}

// MARK: - Handlers

/// **internal use only** Wraps each block submitted to the channel
/// to provide required memory management behavior
final fileprivate class ProducerHandler<Update, Success> {
  public typealias Event = ChannelEvent<Update, Success>
  typealias Block = (_ event: Event, _ on: Executor) -> Void

  let executor: Executor
  let block: Block
  var locking = makeLocking()
  var bufferedUpdates: Queue<Update>?
  var owner: Channel<Update, Success>?

  /// Designated initializer of ProducerHandler
  init(executor: Executor,
       bufferedUpdates: Queue<Update>,
       owner: Channel<Update, Success>,
       block: @escaping Block) {
    self.executor = executor
    self.block = block
    self.bufferedUpdates = bufferedUpdates
    self.owner = owner

    executor.execute(from: nil) { (originalExecutor) in
      self.handleBufferedUpdatesIfNeeded(from: originalExecutor)
    }
  }

  func handleBufferedUpdatesIfNeeded(from originalExecutor: Executor) {
    locking.lock()
    let bufferedUpdates = self.bufferedUpdates
    self.bufferedUpdates = nil
    locking.unlock()

    if let bufferedUpdates = bufferedUpdates {
      for update in bufferedUpdates {
        handle(.update(update), from: originalExecutor)
      }
    }
  }

  func handle(_ value: Event, from originalExecutor: Executor?) {
    self.executor.execute(from: originalExecutor) {
      (originalExecutor) in
      self.handleBufferedUpdatesIfNeeded(from: originalExecutor)
      self.block(value, originalExecutor)
    }
  }

  func releaseOwner() {
    self.owner = nil
  }
}
