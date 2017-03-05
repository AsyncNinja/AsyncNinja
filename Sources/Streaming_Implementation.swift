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
extension Streaming {
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
    cancellationToken: CancellationToken?,
    bufferSize: DerivedChannelBufferSize,
    _ onEvent: @escaping (_ event: Event, _ producer: BaseProducer<P, S>, _ originalExecutor: Executor) throws -> Void
    ) -> BaseProducer<P, S> {
    let bufferSize = bufferSize.bufferSize(self)
    let producer = Producer<P, S>(bufferSize: bufferSize)
    self.attach(producer: producer, executor: executor,
                cancellationToken: cancellationToken, onEvent)
    return producer
  }

  /// **internal use only**
  func attach<T: Streamable>(
    producer: T,
    executor: Executor,
    cancellationToken: CancellationToken?,
    _ onEvent: @escaping (_ event: Event, _ producer: T, _ originalExecutor: Executor) throws -> Void)
  {
    let handler = self.makeHandler(executor: executor) {
      [weak producer] (event, originalExecutor) in
      guard let producer = producer else { return }
      do { try onEvent(event, producer, originalExecutor) }
      catch { producer.fail(error, from: originalExecutor) }
    }

    producer.insertHandlerToReleasePool(handler)
    cancellationToken?.add(cancellable: producer)
  }

  /// **internal use only**
  func makeProducer<P, S, C: ExecutionContext>(
    context: C,
    executor: Executor?,
    cancellationToken: CancellationToken?,
    bufferSize: DerivedChannelBufferSize,
    _ onEvent: @escaping (_ context: C, _ event: Event, _ producer: BaseProducer<P, S>, _ originalExecutor: Executor) throws -> Void
    ) -> BaseProducer<P, S> {
    let bufferSize = bufferSize.bufferSize(self)
    let producer = BaseProducer<P, S>(bufferSize: bufferSize)
    self.attach(producer: producer, context: context, executor: executor,
                cancellationToken: cancellationToken, onEvent)
    return producer
  }

  /// **internal use only**
  func attach<T: Streamable, C: ExecutionContext>(
    producer: T,
    context: C,
    executor: Executor?,
    cancellationToken: CancellationToken?,
    _ onEvent: @escaping (_ context: C, _ event: Event, _ producer: T, _ originalExecutor: Executor) throws -> Void)
  {
    let executor_ = executor ?? context.executor
    self.attach(producer: producer, executor: executor_, cancellationToken: cancellationToken)
    {
      [weak context] (event, producer, originalExecutor) in
      guard let context = context else { return }
      try onEvent(context, event, producer, originalExecutor)
    }

    context.addDependent(completable: producer)
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

  /// Binds events to a specified ProducerProxy
  ///
  /// - Parameters:
  ///   - producerProxy: to bind to
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  func bindEvents<T: Streamable>(
    to producer: T,
    cancellationToken: CancellationToken? = nil) where T.Update == Update, T.Success == Success {
    self.attach(producer: producer,
                executor: .immediate,
                cancellationToken: cancellationToken)
    {
      (event, producer, originalExecutor) in
      switch event {
      case let .update(update):
        producer.update(update, from: originalExecutor)
      case let .completion(.failure(failure)):
        producer.fail(failure, from: originalExecutor)
      case let .completion(.success(success)):
        producer.succeed(success, from: originalExecutor)
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
  func bind<T: Streamable>(
    to updatableProperty: T,
    cancellationToken: CancellationToken? = nil) where T.Update == Update, T.Success == Void {
    self.attach(producer: updatableProperty,
                executor: .immediate,
                cancellationToken: cancellationToken)
    {
      (event, producer, originalExecutor) in
      switch event {
      case let .update(update):
        producer.update(update, from: originalExecutor)
      case let .completion(.failure(failure)):
        producer.fail(failure, from: originalExecutor)
      case .completion(.success):
        producer.succeed(from: originalExecutor)
      }
    }
  }
}
