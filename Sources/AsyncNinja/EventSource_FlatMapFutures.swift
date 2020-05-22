//
//  Copyright (c) 2017 Anton Mironov
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

// swiftlint:disable line_length

/// Flattening Behavior for Channel.flatMap methods
/// that transform update value to future. See cases for details.
public enum ChannelFlatteningBehavior {
  /// perform transformations serially
  /// ![transformSerially](https://github.com/AsyncNinja/AsyncNinja/raw/master/Documentation/Resources/transformSerially.png "transformSerially")
  case transformSerially

  /// send all transformed updates in the order of initial updates arrived
  /// ![orderResults](https://github.com/AsyncNinja/AsyncNinja/raw/master/Documentation/Resources/orderResults.png "orderResults")
  case orderResults

  /// keeps signle latest transform
  /// ![keepLatestTransform](https://github.com/AsyncNinja/AsyncNinja/raw/master/Documentation/Resources/keepLatestTransform.png "keepLatestTransform")
  case keepLatestTransform

  /// drop transformed updates that came out of order
  /// ![dropResultsOutOfOrder](https://github.com/AsyncNinja/AsyncNinja/raw/master/Documentation/Resources/dropResultsOutOfOrder.png "dropResultsOutOfOrder")
  case dropResultsOutOfOrder

  /// send transformed updates as soon as they are arrive
  /// ![keepUnordered](https://github.com/AsyncNinja/AsyncNinja/raw/master/Documentation/Resources/keepUnordered.png "keepUnordered")
  case keepUnordered

  // swiftlint:enable line_length

  /// **internal use only**
  fileprivate func makeImpl<P, S, T>(
    executor: Executor,
    _ transform: @escaping (_ update: P) throws -> Future<T>?
    ) -> BaseFlatteningImpl<P, S, T> {
    switch self {
    case .transformSerially:
      return TransformSeriallyFlatteningImpl(executor: executor, transform: transform)
    case .orderResults:
      return OrderResultsFlatteningImpl(executor: executor, transform: transform)
    case .keepLatestTransform:
      return KeepLatestTransformFlatteningImpl(executor: executor, transform: transform)
    case .dropResultsOutOfOrder:
      return DropResultsOutOfOrderFlatteningImpl(executor: executor, transform: transform)
    case .keepUnordered:
      return KeepUnorderedFlatteningImpl(executor: executor, transform: transform)
    }
  }
}

// MARK: - updates only flattening transformations with futures
public extension EventSource {
  /// Applies transformation to update values of the channel.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply. Completion of a future will be used
  ///     as update value of transformed channel
  ///   - strongContext: context restored from weak reference to specified context
  ///   - update: `Update` to transform
  /// - Returns: transformed channel
  func flatMapWithFallibleUpdate<T, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    behavior: ChannelFlatteningBehavior,
    pure: Bool = true,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ strongContext: C, _ update: Update) throws -> Future<T>
    ) -> Channel<Fallible<T>, Success> {

    let bufferSize = bufferSize.bufferSize(self)
    let producer = Producer<Fallible<T>, Success>(bufferSize: bufferSize)
    let impl: BaseFlatteningImpl<Update, Success, T>
      = behavior.makeImpl(executor: executor ?? context.executor) { [weak context] (update) -> Future<T>? in
        if let context = context {
          return try transform(context, update)
        } else {
          return nil
        }
    }

    context.addDependent(completable: producer)
    self.attach(producer, executor: .immediate, pure: pure, cancellationToken: cancellationToken, impl.onEvent)
    return producer
  }

  /// Applies transformation to update values of the channel.
  ///
  /// - Parameters:
  ///   - executor: to execute transform on
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply. Completion of a future will be used
  ///     as update value of transformed channel
  ///   - update: `Update` to transform
  /// - Returns: transformed channel
  func flatMapWithFallibleUpdate<T>(
    executor: Executor = .primary,
    behavior: ChannelFlatteningBehavior,
    pure: Bool = true,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ update: Update) throws -> Future<T>
    ) -> Channel<Fallible<T>, Success> {

    // Test: EventSource_FlatMapFuturesTests.testFlatMapFutures_KeepUnordered
    // Test: EventSource_FlatMapFuturesTests.testFlatMapFutures_KeepLatestTransform
    // Test: EventSource_FlatMapFuturesTests.testFlatMapFutures_DropResultsOutOfOrder
    // Test: EventSource_FlatMapFuturesTests.testFlatMapFutures_OrderResults
    // Test: EventSource_FlatMapFuturesTests.testFlatMapFutures_TransformSerially

    let bufferSize = bufferSize.bufferSize(self)
    let producer = Producer<Fallible<T>, Success>(bufferSize: bufferSize)
    let impl: BaseFlatteningImpl<Update, Success, T>
      = behavior.makeImpl(executor: executor, transform)
    self.attach(producer, executor: .immediate, pure: pure, cancellationToken: cancellationToken, impl.onEvent)
    return producer
  }
}

// MARK: - updates only flattening transformations with futures
public extension EventSource {
  /// Applies transformation to update values of the channel.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply. Completion of a future will be used
  ///     as update value of transformed channel
  ///   - strongContext: context restored from weak reference to specified context
  ///   - update: `Update` to transform
  /// - Returns: transformed channel
  func flatMap<T, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    behavior: ChannelFlatteningBehavior,
    pure: Bool = true,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ strongContext: C, _ update: Update) throws -> Future<T>
    ) -> Channel<T, Success> {

    return flatMapWithFallibleUpdate(context: context, executor: executor,
                                     behavior: behavior, pure: pure,
                                     cancellationToken: cancellationToken,
                                     bufferSize: bufferSize, transform)
      .unwrapped
  }

  /// Applies transformation to update values of the channel.
  ///
  /// - Parameters:
  ///   - executor: to execute transform on
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply. Completion of a future will be used
  ///     as update value of transformed channel
  ///   - update: `Update` to transform
  /// - Returns: transformed channel
  func flatMap<T>(
    executor: Executor = .primary,
    behavior: ChannelFlatteningBehavior,
    pure: Bool = true,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ update: Update) throws -> Future<T>
    ) -> Channel<T, Success> {

    return flatMapWithFallibleUpdate(executor: executor, behavior: behavior,
                                     pure: pure, cancellationToken: cancellationToken,
                                     bufferSize: bufferSize, transform)
      .unwrapped
  }
}

private class BaseFlatteningImpl<P, S, T> {
  typealias Event = ChannelEvent<P, S>

  let executor: Executor
  let transform: (_ update: P) throws -> Future<T>?
  required init(executor: Executor, transform: @escaping (_ update: P) throws -> Future<T>?) {
    self.executor = executor
    self.transform = transform
  }

  func onEvent(_ event: Event, producer: WeakBox<BaseProducer<Fallible<T>, S>>, from originalExecutor: Executor) {
    assertAbstract()
  }
}

private class KeepUnorderedFlatteningImpl<P, S, T>: BaseFlatteningImpl<P, S, T> {
  override func onEvent(
    _ event: Event,
    producer: WeakBox<BaseProducer<Fallible<T>, S>>,
    from originalExecutor: Executor) {
    switch event {
    case .update(let update):
      executor.execute(from: originalExecutor) { (originalExecutor) in
        let handler = makeFutureOrWrapError({ try self.transform(update) })?
          .makeCompletionHandler(executor: .immediate) { (update, originalExecutor) -> Void in
            producer.value?.update(update, from: originalExecutor)

        }
        producer.value?._asyncNinja_retainHandlerUntilFinalization(handler)
      }
    case .completion(let completion):
      producer.value?.complete(completion, from: originalExecutor)
    }
  }
}

private class KeepLatestTransformFlatteningImpl<P, S, T>: BaseFlatteningImpl<P, S, T> {
  var locking = makeLocking()
  var latestFuture: Future<T?>?

  override func onEvent(
    _ event: Event,
    producer: WeakBox<BaseProducer<Fallible<T>, S>>,
    from originalExecutor: Executor) {
    switch event {
    case .update(let update):
      let promise = Promise<T?>()
      self.locking.lock()
      defer { self.locking.unlock() }
      self.latestFuture = promise
      let handler = promise
        .makeCompletionHandler(
        executor: .immediate
        ) { [weak promise] (update, originalExecutor) -> Void in
          guard let promise = promise else { return }
          self.locking.lock()
          defer { self.locking.unlock() }
          guard self.latestFuture === promise else { return }
          self.latestFuture = nil
          switch update {
          case .success(.some(let value)):
            producer.value?.update(.success(value), from: originalExecutor)
          case .failure(let value):
            producer.value?.update(.failure(value), from: originalExecutor)
          default:
            nop()
          }
      }
      producer.value?._asyncNinja_retainHandlerUntilFinalization(handler)

      executor.execute(from: originalExecutor) { (originalExecutor) in
        do {
          if let future = try self.transform(update) {
            promise.complete(with: future.map(executor: .immediate) { $0 })
          } else {
            promise.succeed(nil, from: originalExecutor)
          }
        } catch {
          promise.fail(error, from: originalExecutor)
        }
      }
    case .completion(let completion):
      producer.value?.complete(completion, from: originalExecutor)
    }
  }
}

private class DropResultsOutOfOrderFlatteningImpl<P, S, T>: BaseFlatteningImpl<P, S, T> {
  var locking = makeLocking()
  var futuresQueue = Queue<(future: Future<T?>, index: Int)>()
  var indexOfNextFuture = 1

  override func onEvent(
    _ event: Event,
    producer: WeakBox<BaseProducer<Fallible<T>, S>>,
    from originalExecutor: Executor) {

    switch event {
    case .update(let update):
      locking.lock()
      let promise = Promise<T?>()
      let index = indexOfNextFuture
      futuresQueue.push((promise, index))
      indexOfNextFuture += 1
      locking.unlock()

      let handler = promise
        .makeCompletionHandler(
          executor: .immediate
        ) { (update, originalExecutor) -> Void in
          self.locking.lock()
          defer { self.locking.unlock() }

          while let first = self.futuresQueue.first {
            if first.index > index {
              break
            } else {
              _ = self.futuresQueue.pop()
              if first.index == index {
                switch update {
                case .success(.some(let value)):
                  producer.value?.update(.success(value), from: originalExecutor)
                case .failure(let value):
                  producer.value?.update(.failure(value), from: originalExecutor)
                default:
                  nop()
                }
              }
            }
          }
      }
      producer.value?._asyncNinja_retainHandlerUntilFinalization(handler)

      executor.execute(from: originalExecutor) { (originalExecutor) in
        do {
          if let future = (try self.transform(update)) {
            promise.complete(with: future.map(executor: .immediate) { $0 })
          } else {
            promise.succeed(nil, from: originalExecutor)
          }
        } catch {
          promise.fail(error, from: originalExecutor)
        }
      }

    case .completion(let completion):
      producer.value?.complete(completion, from: originalExecutor)
    }
  }
}

private class OrderResultsFlatteningImpl<P, S, T>: BaseFlatteningImpl<P, S, T> {
  var locking = makeLocking(isFair: true)
  var futuresQueue = Queue<Future<T?>>()
  var isWaiting = false

  override func onEvent(
    _ event: Event,
    producer: WeakBox<BaseProducer<Fallible<T>, S>>,
    from originalExecutor: Executor) {
    switch event {
    case .update(let update):
      let promise = Promise<T?>()
      locking.lock()
      futuresQueue.push(promise)
      locking.unlock()

      executor.execute(from: originalExecutor) { (originalExecutor) in
        do {
          if let future = try self.transform(update) {
            promise.complete(with: future.map(executor: .immediate) { $0 })
          } else {
            promise.succeed(nil, from: originalExecutor)
          }
        } catch {
          promise.fail(error, from: originalExecutor)
        }
      }

      self.waitForTheNextFutureIfNeeded(producer: producer)
    case .completion(let completion):
      producer.value?.complete(completion, from: originalExecutor)
    }
  }

  private func waitForTheNextFutureIfNeeded(producer: WeakBox<BaseProducer<Fallible<T>, S>>) {
    locking.lock()
    guard
      !isWaiting,
      let future = futuresQueue.pop()
      else {
        locking.unlock()
        return
    }

    isWaiting = true
    locking.unlock()

    let handler = future
      .makeCompletionHandler(
        executor: .immediate
      ) { [weak weakSelf = self] (update, originalExecutor) -> Void in

        switch update {
        case .success(.some(let value)):
          producer.value?.update(.success(value), from: originalExecutor)
        case .failure(let value):
          producer.value?.update(.failure(value), from: originalExecutor)
        default:
          nop()
        }

        guard let self_ = weakSelf else { return }
        self_.locking.lock()
        self_.isWaiting = false
        self_.locking.unlock()
        self_.waitForTheNextFutureIfNeeded(producer: producer)
    }
    producer.value?._asyncNinja_retainHandlerUntilFinalization(handler)
  }
}

private class TransformSeriallyFlatteningImpl<P, S, T>: BaseFlatteningImpl<P, S, T> {
  var locking = makeLocking(isFair: true)
  var updatesQueue = Queue<P>()
  var isRunning = false

  override func onEvent(
    _ event: Event,
    producer: WeakBox<BaseProducer<Fallible<T>, S>>,
    from originalExecutor: Executor) {
    switch event {
    case .update(let update):
      locking.lock()
      defer { locking.unlock() }
      updatesQueue.push(update)
      launchNextTransformIfNeeded(producer: producer, from: originalExecutor)
    case .completion(let completion):
      producer.value?.complete(completion, from: originalExecutor)
    }
  }

  private func launchNextTransformIfNeeded(
    producer: WeakBox<BaseProducer<Fallible<T>, S>>,
    from originalExecutor: Executor) {
    guard
      !isRunning,
      let update = updatesQueue.pop()
      else { return }

    isRunning = true
    let promise = Promise<T?>()
    executor.execute(from: originalExecutor) { (originalExecutor) in
      do {
        if let future = try self.transform(update) {
          promise.complete(with: future.map(executor: .immediate) { $0 })
        } else {
          promise.succeed(nil, from: originalExecutor)
        }
      } catch {
        promise.fail(error, from: originalExecutor)
      }
    }

    let handler = promise
      .makeCompletionHandler(
        executor: .immediate
      ) { [weak weakSelf = self] (update, originalExecutor) -> Void in
        switch update {
        case .success(.some(let value)):
          producer.value?.update(.success(value), from: originalExecutor)
        case .failure(let value):
          producer.value?.update(.failure(value), from: originalExecutor)
        default:
          nop()
        }

        guard let self_ = weakSelf else { return }
        self_.locking.lock()
        defer { self_.locking.unlock() }
        self_.isRunning = false
        self_.launchNextTransformIfNeeded(producer: producer, from: originalExecutor)
    }
    producer.value?._asyncNinja_retainHandlerUntilFinalization(handler)
  }
}
