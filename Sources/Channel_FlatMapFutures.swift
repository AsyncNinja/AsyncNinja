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

/// Flattening Behavior for Channel.flatMapPeriodic methods
/// that transform periodic value to future. See cases for details.
public enum ChannelFlatteningBehavior {
  /// perform transformations serially
  /// ![transformSerially](https://github.com/AsyncNinja/AsyncNinja/raw/master/Documentation/Resources/transformSerially.png "transformSerially")
  case transformSerially

  /// send all transformed periodics in the order of initial periodics arrived
  /// ![orderResults](https://github.com/AsyncNinja/AsyncNinja/raw/master/Documentation/Resources/orderResults.png "orderResults")
  case orderResults

  /// keeps signle latest transform
  /// ![keepLatestTransform](https://github.com/AsyncNinja/AsyncNinja/raw/master/Documentation/Resources/keepLatestTransform.png "keepLatestTransform")
  case keepLatestTransform

  /// drop transformed periodics that came out of order
  /// ![dropResultsOutOfOrder](https://github.com/AsyncNinja/AsyncNinja/raw/master/Documentation/Resources/dropResultsOutOfOrder.png "dropResultsOutOfOrder")
  case dropResultsOutOfOrder

  /// send transformed periodics as soon as they are arrive
  /// ![keepUnordered](https://github.com/AsyncNinja/AsyncNinja/raw/master/Documentation/Resources/keepUnordered.png "keepUnordered")
  case keepUnordered

  /// **internal use only**
  fileprivate func makeStorage<P, S, T>(
    executor: Executor,
    _ transform: @escaping (_ periodic: P) throws -> Future<T>?
    ) -> BaseChannelFlatteningBehaviorStorage<P, S, T> {
    switch self {
    case .transformSerially:
      return TransformSeriallyChannelFlatteningBehaviorStorage(executor: executor, transform: transform)
    case .orderResults:
      return OrderResultsChannelFlatteningBehaviorStorage(executor: executor, transform: transform)
    case .keepLatestTransform:
      return KeepLatestTransformChannelFlatteningBehaviorStorage(executor: executor, transform: transform)
    case .dropResultsOutOfOrder:
      return DropResultsOutOfOrderChannelFlatteningBehaviorStorage(executor: executor, transform: transform)
    case .keepUnordered:
      return KeepUnorderedChannelFlatteningBehaviorStorage(executor: executor, transform: transform)
    }
  }
}

// MARK: - periodics only flattening transformations with futures
public extension Channel {
  /// Applies transformation to periodic values of the channel.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply. Completion of a future will be used
  ///     as periodic value of transformed channel
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodic: `Periodic` to transform
  /// - Returns: transformed channel
  func flatMapPeriodic<T, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    behavior: ChannelFlatteningBehavior,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ strongContext: C, _ periodic: Periodic) throws -> Future<T>
    ) -> Channel<Fallible<T>, Success> {

    let bufferSize = bufferSize.bufferSize(self)
    let producer = Producer<Fallible<T>, Success>(bufferSize: bufferSize)
    let storage: BaseChannelFlatteningBehaviorStorage<Periodic, Success, T>
      = behavior.makeStorage(executor: executor ?? context.executor) { [weak context] (periodic) -> Future<T>? in
      if let context = context {
        return try transform(context, periodic)
      } else {
        return nil
      }
    }

    context.addDependent(completable: producer)
    self.attach(producer: producer, executor: .immediate, cancellationToken: cancellationToken, storage.onValue)
    return producer
  }

  /// Applies transformation to periodic values of the channel.
  ///
  /// - Parameters:
  ///   - executor: to execute transform on
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply. Completion of a future will be used
  ///     as periodic value of transformed channel
  ///   - periodic: `Periodic` to transform
  /// - Returns: transformed channel
  func flatMapPeriodic<T>(
    executor: Executor = .primary,
    behavior: ChannelFlatteningBehavior,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ periodic: Periodic) throws -> Future<T>
    ) -> Channel<Fallible<T>, Success> {

    // Test: Channel_FlatMapFuturesTests.testFlatMapFutures_KeepUnordered
    // Test: Channel_FlatMapFuturesTests.testFlatMapFutures_KeepLatestTransform
    // Test: Channel_FlatMapFuturesTests.testFlatMapFutures_DropResultsOutOfOrder
    // Test: Channel_FlatMapFuturesTests.testFlatMapFutures_OrderResults
    // Test: Channel_FlatMapFuturesTests.testFlatMapFutures_TransformSerially

    let bufferSize = bufferSize.bufferSize(self)
    let producer = Producer<Fallible<T>, Success>(bufferSize: bufferSize)
    let storage: BaseChannelFlatteningBehaviorStorage<Periodic, Success, T>
      = behavior.makeStorage(executor: executor, transform)
    self.attach(producer: producer, executor: .immediate, cancellationToken: cancellationToken, storage.onValue)
    return producer
  }
}


private class BaseChannelFlatteningBehaviorStorage<P, S, T> {
  let executor: Executor
  let transform: (_ periodic: P) throws -> Future<T>?
  required init(executor: Executor, transform: @escaping (_ periodic: P) throws -> Future<T>?) {
    self.executor = executor
    self.transform = transform
  }

  func onValue(value: ChannelValue<P, S>, producer: Producer<Fallible<T>, S>) {
    assertAbstract()
  }
}

private class KeepUnorderedChannelFlatteningBehaviorStorage<P, S, T>: BaseChannelFlatteningBehaviorStorage<P, S, T> {
  override func onValue(value: ChannelValue<P, S>, producer: Producer<Fallible<T>, S>) {
    switch value {
    case .periodic(let periodic):
      executor.execute {
        let handler = makeFutureOrWrapError({ try self.transform(periodic) })?
          .makeCompletionHandler(executor: .immediate) { [weak producer] (periodic) -> Void in
            producer?.send(periodic)

        }
        producer.insertHandlerToReleasePool(handler)
      }
    case .completion(let completion):
      producer.complete(with: completion)
    }
  }
}

private class KeepLatestTransformChannelFlatteningBehaviorStorage<P, S, T>: BaseChannelFlatteningBehaviorStorage<P, S, T> {
  var locking = makeLocking()
  var latestFuture: Future<T?>?

  override func onValue(value: ChannelValue<P, S>, producer: Producer<Fallible<T>, S>) {
    switch value {
    case .periodic(let periodic):
      let promise = Promise<T?>()
      self.locking.lock()
      defer { self.locking.unlock() }
      self.latestFuture = promise
      let handler = promise
        .makeCompletionHandler(executor: .immediate) { [weak producer, weak promise] (periodic) -> Void in
          guard let producer = producer, let promise = promise else { return }
          self.locking.lock()
          defer { self.locking.unlock() }
          guard self.latestFuture === promise else { return }
          self.latestFuture = nil
          switch periodic {
          case .success(.some(let value)):
            producer.send(.success(value))
          case .failure(let value):
            producer.send(.failure(value))
          default:
            nop()
          }
      }
      producer.insertHandlerToReleasePool(handler)

      executor.execute {
        do {
          if let future = try self.transform(periodic) {
            promise.complete(with: future.map(executor: .immediate) { $0 } )
          } else {
            promise.succeed(with: nil)
          }
        } catch {
          promise.fail(with: error)
        }
      }
    case .completion(let completion):
      producer.complete(with: completion)
    }
  }
}

private class DropResultsOutOfOrderChannelFlatteningBehaviorStorage<P, S, T>: BaseChannelFlatteningBehaviorStorage<P, S, T> {
  var locking = makeLocking()
  let futuresQueue = Queue<(future: Future<T?>, index: Int)>()
  var indexOfNextFuture = 1

  override func onValue(value: ChannelValue<P, S>, producer: Producer<Fallible<T>, S>) {

    switch value {
    case .periodic(let periodic):
      locking.lock()
      let promise = Promise<T?>()
      let index = indexOfNextFuture
      futuresQueue.push((promise, index))
      indexOfNextFuture += 1
      locking.unlock()

      let handler = promise
        .makeCompletionHandler(executor: .immediate) { [weak producer] (periodic) -> Void in
          guard
            let producer = producer
            else { return }
          self.locking.lock()
          defer { self.locking.unlock() }

          while let first = self.futuresQueue.first {
            if first.index > index {
              break
            } else {
              let _ = self.futuresQueue.pop()
              if first.index == index {
                switch periodic {
                case .success(.some(let value)):
                  producer.send(.success(value))
                case .failure(let value):
                  producer.send(.failure(value))
                default:
                  nop()
                }
              }
            }
          }
      }
      producer.insertHandlerToReleasePool(handler)

      executor.execute {
        do {
          if let future = (try self.transform(periodic)) {
            promise.complete(with: future.map(executor: .immediate) { $0 } )
          } else {
            promise.succeed(with: nil)
          }
        } catch {
          promise.fail(with: error)
        }
      }

    case .completion(let completion):
      producer.complete(with: completion)
    }
  }
}


private class OrderResultsChannelFlatteningBehaviorStorage<P, S, T>: BaseChannelFlatteningBehaviorStorage<P, S, T> {
  var locking = makeLocking(isFair: true)
  let futuresQueue = Queue<Future<T?>>()
  var isWaiting = false

  override func onValue(value: ChannelValue<P, S>, producer: Producer<Fallible<T>, S>) {
    switch value {
    case .periodic(let periodic):
      let promise = Promise<T?>()
      locking.lock()
      futuresQueue.push(promise)
      locking.unlock()

      executor.execute {
        do {
          if let future = try self.transform(periodic) {
            promise.complete(with: future.map(executor: .immediate) { $0 } )
          } else {
            promise.succeed(with: nil)
          }
        } catch {
          promise.fail(with: error)
        }
      }

      self.waitForTheNextFutureIfNeeded(producer: producer)
    case .completion(let completion):
      producer.complete(with: completion)
    }
  }

  private func waitForTheNextFutureIfNeeded(producer: Producer<Fallible<T>, S>) {
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
      .makeCompletionHandler(executor: .immediate) { [weak producer, weak weakSelf = self] (periodic) -> Void in
        guard let producer = producer else { return }

        switch periodic {
        case .success(.some(let value)):
          producer.send(.success(value))
        case .failure(let value):
          producer.send(.failure(value))
        default:
          nop()
        }

        guard let self_ = weakSelf else { return }
        self_.locking.lock()
        self_.isWaiting = false
        self_.locking.unlock()
        self_.waitForTheNextFutureIfNeeded(producer: producer)
    }
    producer.insertHandlerToReleasePool(handler)
  }
}

private class TransformSeriallyChannelFlatteningBehaviorStorage<P, S, T>: BaseChannelFlatteningBehaviorStorage<P, S, T> {
  var locking = makeLocking(isFair: true)
  let periodicsQueue = Queue<P>()
  var isRunning = false

  override func onValue(value: ChannelValue<P, S>, producer: Producer<Fallible<T>, S>) {
    switch value {
    case .periodic(let periodic):
      locking.lock()
      defer { locking.unlock() }
      periodicsQueue.push(periodic)
      self.launchNextTransformIfNeeded(producer: producer)
    case .completion(let completion):
      producer.complete(with: completion)
    }
  }

  private func launchNextTransformIfNeeded(producer: Producer<Fallible<T>, S>) {
    guard
      !isRunning,
      let periodic = periodicsQueue.pop()
      else { return }

    isRunning = true
    let promise = Promise<T?>()
    executor.execute {
      do {
        if let future = try self.transform(periodic) {
          promise.complete(with: future.map(executor: .immediate) { $0 } )
        } else {
          promise.succeed(with: nil)
        }
      } catch {
        promise.fail(with: error)
      }
    }

    let handler = promise
      .makeCompletionHandler(executor: .immediate) { [weak producer, weak weakSelf = self] (periodic) -> Void in
        guard let producer = producer else { return }
        switch periodic {
        case .success(.some(let value)):
          producer.send(.success(value))
        case .failure(let value):
          producer.send(.failure(value))
        default:
          nop()
        }

        guard let self_ = weakSelf else { return }
        self_.locking.lock()
        defer { self_.locking.unlock() }
        self_.isRunning = false
        self_.launchNextTransformIfNeeded(producer: producer)
    }
    producer.insertHandlerToReleasePool(handler)
  }
}
