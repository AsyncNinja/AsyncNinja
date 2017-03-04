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

/// represents values that updateally arrive followed by failure of completion that completes Channel. Channel oftenly represents result of long running task that is not yet arrived and flow of some intermediate results.
public class Channel<Update, Success>: Completing, Sequence {
  public typealias Event = ChannelEvent<Update, Success>
  public typealias Handler = ChannelHandler<Update, Success>
  public typealias Iterator = ChannelIterator<Update, Success>

  /// completion of channel. Returns nil if channel is not complete yet
  public var completion: Fallible<Success>? { assertAbstract() }

  /// amount of currently stored updates
  public var bufferSize: Int { assertAbstract() }

  /// maximal amount of updates store
  public var maxBufferSize: Int { assertAbstract() }

  init() { }

  /// **internal use only**
  final public func makeCompletionHandler(
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> Handler? {
    return self.makeHandler(executor: executor) {
      (event, originalExecutor) in
      if case .completion(let completion) = event {
        block(completion, originalExecutor)
      }
    }
  }

  /// **internal use only**
  final public func makeUpdateHandler(
    executor: Executor,
    _ block: @escaping (_ update: Update, _ originalExecutor: Executor) -> Void
    ) -> Handler? {
    return self.makeHandler(executor: executor) {
      (event, originalExecutor) in
      if case .update(let update) = event {
        block(update, originalExecutor)
      }
    }
  }

  /// **internal use only**
  public func makeHandler(
    executor: Executor,
    _ block: @escaping (_ event: Event, _ originalExecutor: Executor) -> Void) -> Handler? {
    assertAbstract()
  }

  /// Makes an iterator that allows synchronous iteration over update values of the channel
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
    return description(withBody: "Channel<\(Update.self), \(Success.self)>")
  }

  /// **internal use only**
  private func description(withBody body: String) -> String {
    switch completion {
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
  /// Subscribes for buffered and new values (both update and completion) for the channel
  ///
  /// - Parameters:
  ///   - executor: to execute block on
  ///   - block: to execute. Will be called multiple times
  ///   - event: received by the channel
  func onEvent(
    executor: Executor = .primary,
    _ block: @escaping (_ event: Event) -> Void) {
    let handler = self.makeHandler(executor: executor) {
      (event, originalExecutor) in
      block(event)
    }
    self.insertHandlerToReleasePool(handler)
  }

  /// Subscribes for buffered and new values (both update and completion) for the channel
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need
  ///     to override an executor provided by the context
  ///   - block: to execute. Will be called multiple times
  ///   - strongContext: context restored from weak reference to specified context
  ///   - event: received by the channel
  func onEvent<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ block: @escaping (_ strongContext: C, _ event: Event) -> Void) {

    let handler = self.makeHandler(executor: executor ?? context.executor)
    {
      [weak context] (event, originalExecutor) in
      guard let context = context else { return }
      block(context, event)
    }

    if let handler = handler {
      context.releaseOnDeinit(handler)
    }
  }
  
  /// Subscribes for buffered and new update values for the channel
  ///
  /// - Parameters:
  ///   - executor: to execute block on
  ///   - block: to execute. Will be called multiple times
  ///   - update: received by the channel
  func onUpdate(
    executor: Executor = .primary,
    _ block: @escaping (_ update: Update) -> Void) {
    self.onEvent(executor: executor) { (event) in
      switch event {
      case let .update(update):
        block(update)
      case .completion: nop()
      }
    }
  }
  
  /// Binds events to a specified ProducerProxy
  ///
  /// - Parameters:
  ///   - producerProxy: to bind to
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  func bindEvents(
    to producerProxy: ProducerProxy<Update, Success>,
    cancellationToken: CancellationToken? = nil) {
    self.attach(producer: producerProxy,
                executor: .immediate,
                cancellationToken: cancellationToken)
    {
      (event, producer, originalExecutor) in
      producer.apply(event, from: originalExecutor)
    }
  }

  /// Binds updates to a specified UpdatableProperty
  ///
  /// - Parameters:
  ///   - updatableProperty: to bind to
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  func bind(
    to updatableProperty: ProducerProxy<Update, Void>,
    cancellationToken: CancellationToken? = nil) {
    self.attach(producer: updatableProperty,
                executor: .immediate,
                cancellationToken: cancellationToken)
    {
      (event, producer, originalExecutor) in
      switch event {
      case let .update(update):
        producer.update(update, from: originalExecutor)
      case let .completion(.failure(failure)):
        producer.fail(with: failure, from: originalExecutor)
      case .completion(.success):
        producer.succeed(from: originalExecutor)
      }
    }
  }

  /// Subscribes for buffered and new update values for the channel
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need
  ///     to override an executor provided by the context
  ///   - block: to execute. Will be called multiple times
  ///   - strongContext: context restored from weak reference to specified context
  ///   - update: received by the channel
  func onUpdate<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ block: @escaping (_ strongContext: C, _ update: Update) -> Void) {
    self.onEvent(context: context, executor: executor) { (context, value) in
      switch value {
      case let .update(update):
        block(context, update)
      case .completion: nop()
      }
    }
  }

  /// Subscribes for all buffered and new values (both update and completion) for the channel
  ///
  /// - Parameters:
  ///   - executor: to execute block on
  ///   - block: to execute. Will be called once with all values
  ///   - updates: all received by the channel
  ///   - completion: received by the channel
  func extractAll(
    executor: Executor = .primary,
    _ block: @escaping (_ updates: [Update], _ completion: Fallible<Success>) -> Void) {
    var updates = [Update]()
    let executor_ = executor.makeDerivedSerialExecutor()
    self.onEvent(executor: executor_) { (event) in
      switch event {
      case let .update(update):
        updates.append(update)
      case let .completion(completion):
        block(updates, completion)
      }
    }
  }

  /// Subscribes for all buffered and new values (both update and completion) for the channel
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need
  ///     to override an executor provided by the context
  ///   - block: to execute. Will be called once with all values
  ///   - strongContext: context restored from weak reference to specified context
  ///   - updates: all received by the channel
  ///   - completion: received by the channel
  func extractAll<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ block: @escaping (_ strongContext: C, _ updates: [Update], _ completion: Fallible<Success>) -> Void) {
    var updates = [Update]()
    let executor_ = (executor ?? context.executor).makeDerivedSerialExecutor()
    self.onEvent(context: context, executor: executor_) { (context, value) in
      switch value {
      case let .update(update):
        updates.append(update)
      case let .completion(completion):
        block(context, updates, completion)
      }
    }
  }

  /// Synchronously waits for channel to complete. Returns all updates and completion
  func waitForAll() -> (updates: [Update], completion: Fallible<Success>) {
    return (self.map { $0 }, self.completion!)
  }
}

// MARK: - Iterators

/// Synchronously iterates over each update value of channel
public struct ChannelIterator<Update, Success>: IteratorProtocol  {
  public typealias Element = Update
  private var _implBox: Box<ChannelIteratorImpl<Update, Success>> // want to have reference to reference, because impl may actually be retained by some handler

  /// completion of the channel. Will be available as soon as the channel completes.
  public var completion: Fallible<Success>? { return _implBox.value.completion }

  /// success of the channel. Will be available as soon as the channel completes with success.
  public var success: Success? { return _implBox.value.completion?.success }
  
  /// failure of the channel. Will be available as soon as the channel completes with failure.
  public var filure: Swift.Error? { return _implBox.value.completion?.failure }

  /// **internal use only** Designated initializer
  init(impl: ChannelIteratorImpl<Update, Success>) {
    _implBox = Box(impl)
  }

  /// fetches next value from the channel.
  /// Waits for the next value to appear.
  /// Returns nil when then channel completes
  public mutating func next() -> Update? {
    if !isKnownUniquelyReferenced(&_implBox) {
      _implBox = Box(_implBox.value.clone())
    }
    return _implBox.value.next()
  }
}

/// **Internal use only**
class ChannelIteratorImpl<Update, Success>  {
  public typealias Element = Update
  var completion: Fallible<Success>? { assertAbstract() }

  init() { }

  public func next() -> Update? {
    assertAbstract()
  }

  func clone() -> ChannelIteratorImpl<Update, Success> {
    assertAbstract()
  }
}

/// Value reveived by channel
public enum ChannelEvent<Update, Success> {
  /// A kind of value that can be received multiple times be for the completion one
  case update(Update)

  /// A kind of value that can be received once and completes the channel
  case completion(Fallible<Success>)
}

// MARK: - Handlers

/// **internal use only** Wraps each block submitted to the channel
/// to provide required memory management behavior
final public class ChannelHandler<Update, Success> {
  public typealias Event = ChannelEvent<Update, Success>
  typealias Block = (_ event: Event, _ on: Executor) -> Void

  let executor: Executor
  let block: Block
  var locking = makeLocking()
  var bufferedUpdates: Queue<Update>?
  var owner: Channel<Update, Success>?

  /// Designated initializer of ChannelHandler
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
