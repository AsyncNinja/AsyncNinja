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

// MARK: - internal methods
extension EventSource {
  /// **internal use only**
  final public func makeCompletionHandler(
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> AnyObject? {
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
    ) -> AnyObject? {
    return self.makeHandler(executor: executor) {
      (event, originalExecutor) in
      if case .update(let update) = event {
        block(update, originalExecutor)
      }
    }
  }

  /// **internal use only**
  func makeProducer<P, S>(
    executor: Executor,
    pure: Bool,
    cancellationToken: CancellationToken?,
    bufferSize: DerivedChannelBufferSize,
    _ onEvent: @escaping (_ event: Event, _ producer: WeakBox<BaseProducer<P, S>>, _ originalExecutor: Executor) throws -> Void
    ) -> BaseProducer<P, S>
  {
    let bufferSize = bufferSize.bufferSize(self)
    let producer = Producer<P, S>(bufferSize: bufferSize)
    self.attach(producer, executor: executor, pure: pure,
                cancellationToken: cancellationToken, onEvent)
    return producer
  }

  /// **internal use only**
  func attach<T: EventsDestination>(
    _ eventsDestination: T,
    executor: Executor,
    pure: Bool,
    cancellationToken: CancellationToken?,
    _ onEvent: @escaping (_ event: Event, _ eventsDestination: WeakBox<T>, _ originalExecutor: Executor) throws -> Void)
  {
    let weakBoxOfEventsDestination = WeakBox(eventsDestination)
    let handler = self.makeHandler(executor: executor)
    { (event, originalExecutor) in
      if pure, case .none = weakBoxOfEventsDestination.value { return }
      do { try onEvent(event, weakBoxOfEventsDestination, originalExecutor) }
      catch { weakBoxOfEventsDestination.value?.fail(error, from: originalExecutor) }
    }

    if let handler = handler {
      if pure {
        let box = MutableBox<AnyObject?>(handler)
        self._asyncNinja_retainUntilFinalization(HalfRetainer(box: box))
        eventsDestination._asyncNinja_retainUntilFinalization(HalfRetainer(box: box))
      } else {
        self._asyncNinja_retainUntilFinalization(handler)
      }
    }

    cancellationToken?.add(cancellable: eventsDestination)
  }

  /// **internal use only**
  func makeProducer<P, S, C: ExecutionContext>(
    context: C,
    executor: Executor?,
    pure: Bool,
    cancellationToken: CancellationToken?,
    bufferSize: DerivedChannelBufferSize,
    _ onEvent: @escaping (_ context: C, _ event: Event, _ producer: WeakBox<BaseProducer<P, S>>, _ originalExecutor: Executor) throws -> Void
    ) -> BaseProducer<P, S>
  {
    let bufferSize = bufferSize.bufferSize(self)
    let producer = BaseProducer<P, S>(bufferSize: bufferSize)
    self.attach(producer, context: context, executor: executor, pure: pure,
                cancellationToken: cancellationToken, onEvent)
    return producer
  }

  /// **internal use only**
  func attach<T: EventsDestination, C: ExecutionContext>(
    _ eventsDestination: T,
    context: C,
    executor: Executor?,
    pure: Bool,
    cancellationToken: CancellationToken?,
    _ onEvent: @escaping (_ context: C, _ event: Event, _ producer: WeakBox<T>, _ originalExecutor: Executor) throws -> Void)
  {
    let executor_ = executor ?? context.executor
    self.attach(eventsDestination, executor: executor_, pure: pure, cancellationToken: cancellationToken)
    { [weak context] (event, producer, originalExecutor) in
      guard let context = context else { return }
      try onEvent(context, event, producer, originalExecutor)
    }

    context.addDependent(completable: eventsDestination)
  }
}

public extension EventSource {
  /// **internal use only**
  func _onEvent(
    executor: Executor = .primary,
    _ block: @escaping (_ event: Event, _ originalExecutor: Executor) -> Void) {
    let handler = self.makeHandler(executor: executor, block)
    self._asyncNinja_retainHandlerUntilFinalization(handler)
  }

  /// **internal use only**
  func _onEvent<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ block: @escaping (_ strongContext: C, _ event: Event, _ originalExecutor: Executor) -> Void) {

    let handler = self.makeHandler(executor: executor ?? context.executor)
    { [weak context] (event, originalExecutor) in
      if let context = context {
        block(context, event, originalExecutor)
      }
    }
    if let handler = handler {
      context.releaseOnDeinit(handler)
    }
  }

  /// Subscribes for buffered and new values (both update and completion) for the channel
  ///
  /// - Parameters:
  ///   - executor: to execute block on
  ///   - block: to execute. Will be called multiple times
  ///   - event: received by the channel
  func onEvent(
    executor: Executor = .primary,
    _ block: @escaping (_ event: Event) -> Void) {
    _onEvent { (event, originalExecutor) in
      block(event)
    }
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
    _onEvent(context: context, executor: executor) {
      (context, event, originalExecutor) in
      block(context, event)
    }
  }

  /// Makes a future of accumulated updates and completion
  func extractAll() -> Future<(updates: [Update], completion: Fallible<Success>)> {
    var updates = [Update]()
    var locking = makeLocking(isFair: true)
    let promise = Promise<(updates: [Update], completion: Fallible<Success>)>()
    let handler = self.makeHandler(executor: .immediate) { [weak promise] (event, originalExecutor) in
      switch event {
      case let .update(update):
        locking.lock()
        updates.append(update)
        locking.unlock()
      case let .completion(completion):
        locking.lock()
        let finalUpdates = updates
        locking.unlock()
        promise?.succeed((finalUpdates, completion))
      }
    }
    promise._asyncNinja_retainHandlerUntilFinalization(handler)
    return promise
  }

  /// Binds events to a specified ProducerProxy
  ///
  /// - Parameters:
  ///   - producerProxy: to bind to
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  func bindEvents<T: EventsDestination>(
    _ eventsDestination: T,
    cancellationToken: CancellationToken? = nil
    ) where T.Update == Update, T.Success == Success {
    self.attach(eventsDestination,
                executor: .immediate,
                pure: true,
                cancellationToken: cancellationToken)
    {
      (event, producer, originalExecutor) in
      switch event {
      case let .update(update):
        producer.value?.update(update, from: originalExecutor)
      case let .completion(.failure(failure)):
        producer.value?.fail(failure, from: originalExecutor)
      case let .completion(.success(success)):
        producer.value?.succeed(success, from: originalExecutor)
      }
    }
  }

  /// Binds updates to a specified UpdatableProperty
  ///
  /// - Parameters:
  ///   - updatableProperty: to bind to
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  func bind<T: EventsDestination>(
    _ eventsDestination: T,
    cancellationToken: CancellationToken? = nil
    ) where T.Update == Update, T.Success == Void {
    self.attach(eventsDestination,
                executor: .immediate,
                pure: true,
                cancellationToken: cancellationToken)
    {
      (event, producer, originalExecutor) in
      switch event {
      case let .update(update):
        producer.value?.update(update, from: originalExecutor)
      case let .completion(.failure(failure)):
        producer.value?.fail(failure, from: originalExecutor)
      case .completion(.success):
        producer.value?.succeed(from: originalExecutor)
      }
    }
  }
}

/// Binds two event streams bidirectionally.
///
/// - Parameters:
///   - majorStream: a stream to bind to. This stream has a priority during initial synchronization
///   - transform: for T.Update -> U.Update
///   - minorStream: a stream to bind to.
///   - reverseTransform: for U.Update -> T.Update
public func doubleBind<T: EventSource&EventsDestination, U: EventSource&EventsDestination>(
  _ majorStream: T,
  transform: @escaping (T.Update) -> U.Update,
  _ minorStream: U,
  reverseTransform: @escaping (U.Update) -> T.Update)
{
  var locking = makeLocking(isFair: true)
  var majorRevision = 1
  var minorRevision = 0

  let minorHandler = minorStream.makeUpdateHandler(executor: .immediate) {
    [weak majorStream] (update, originalExecutor) in
    locking.lock()
    if minorRevision >= majorRevision {
      minorRevision += 1
      locking.unlock()
      majorStream?.update(reverseTransform(update), from: originalExecutor)
    } else {
      minorRevision = majorRevision
      locking.unlock()
    }
  }

  if let minorHandler = minorHandler {
    let box = MutableBox<AnyObject?>(minorHandler)
    majorStream._asyncNinja_retainUntilFinalization(HalfRetainer(box: box))
    minorStream._asyncNinja_retainUntilFinalization(HalfRetainer(box: box))
  }

  let majorHandler = majorStream.makeUpdateHandler(executor: .immediate) {
    [weak minorStream] (update, originalExecutor) in
    locking.lock()
    if majorRevision >= minorRevision {
      majorRevision += 1
      locking.unlock()
      minorStream?.update(transform(update), from: originalExecutor)
    } else {
      majorRevision = minorRevision
      locking.unlock()
    }
  }

  if let majorHandler = majorHandler {
    let box = MutableBox<AnyObject?>(majorHandler)
    majorStream._asyncNinja_retainUntilFinalization(HalfRetainer(box: box))
    minorStream._asyncNinja_retainUntilFinalization(HalfRetainer(box: box))
  }
}

/// Binds two event streams bidirectionally.
///
/// - Parameters:
///   - majorStream: a stream to bind to. This stream has a priority during initial synchronization
///   - minorStream: a stream to bind to.
public func doubleBind<T: EventSource&EventsDestination, U: EventSource&EventsDestination>(
  _ majorStream: T,
  _ minorStream: U
  ) where T.Update == U.Update
{
  doubleBind(majorStream, transform: { $0 }, minorStream, reverseTransform: { $0 })
}
