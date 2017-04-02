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

// MARK: - scan

public extension EventSource {

  private func _scan<Result>(
    _ initialResult: Result,
    executor: Executor = .immediate,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ nextPartialResult: @escaping (Result, Update) throws -> Result
    ) -> BaseProducer<Result, (Result, Success)>
  {
    var locking = makeLocking(isFair: true)
    var partialResult = initialResult
    let queue = Queue<Event>()

    return self.makeProducer(executor: .immediate, pure: true, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (event, producer, originalExecutor) in
      locking.lock()
      queue.push(event)
      locking.unlock()

      executor.execute(from: originalExecutor) {
        (originalExecutor) in
        let event: ChannelEvent<Result, (Result, Success)> = locking.locker {
          let event = queue.pop()!
          switch event {
          case let .update(update):
            do {
              partialResult = try nextPartialResult(partialResult, update)
              return .update(partialResult)
            } catch {
              return .failure(error)
            }
          case .completion(.success(let successValue)):
            return .success((partialResult, successValue))
          case let .completion(.failure(failure)):
            return .failure(failure)
          }
        }

        producer.value?.post(event)
      }
    }
  }

  /// Returns channel of the result of calling the given combining closure
  /// with each update value of this channel and an accumulating value.
  ///
  /// - Parameters:
  ///   - initialResult: the initial accumulating value.
  ///   - context: `ExectionContext` to call accumulation closure on
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - executor: to execute call predicate on accumulation closure on
  ///   - cancellationToken: CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - nextPartialResult: A closure that combines an accumulating
  ///     value and a update value of the channel into a new accumulating
  ///     value, to be used in the next call of the `nextPartialResult`
  ///     closure or returned to the caller.
  /// - Returns: The future tuple of accumulated completion and success of channel.
  func scan<Result, C: ExecutionContext>(
    _ initialResult: Result,
    context: C,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ nextPartialResult: @escaping (C, Result, Update) throws -> Result
    ) -> Channel<Result, (Result, Success)>  {

    // Test: EventSource_ToFutureTests.testScanContextual

    let _executor = executor ?? context.executor
    let promise = _scan(initialResult, executor: _executor, cancellationToken: cancellationToken) {
      [weak context] (accumulator, value) -> Result in
      guard let context = context
        else { throw AsyncNinjaError.contextDeallocated }

      return try nextPartialResult(context, accumulator, value)
    }

    context.addDependent(completable: promise)

    return promise
  }

  /// Returns channel of the result of calling the given combining closure
  /// with each update value of this channel and an accumulating value.
  ///
  /// - Parameters:
  ///   - initialResult: the initial accumulating value.
  ///   - context: `ExectionContext` to call accumulation closure on
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - executor: to execute call predicate on accumulation closure on
  ///   - cancellationToken: CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - nextPartialResult: A closure that combines an accumulating
  ///     value and a update value of the channel into a new accumulating
  ///     value, to be used in the next call of the `nextPartialResult`
  ///     closure or returned to the caller.
  /// - Returns: The future tuple of accumulated completion and success of channel.
  func scan<Result>(
    _ initialResult: Result,
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ nextPartialResult: @escaping (Result, Update) throws -> Result
    ) -> Channel<Result, (Result, Success)>
  {
    // Test: EventSource_ToFutureTests.testScan
    return _scan(initialResult,
                 executor: executor,
                 cancellationToken: cancellationToken,
                 bufferSize: bufferSize,
                 nextPartialResult)
  }
}

// MARK: - reduce

public extension EventSource {

  /// **internal use only**
  private func _reduce<Result>(
    _ initialResult: Result,
    executor: Executor,
    cancellationToken: CancellationToken?,
    _ nextPartialResult: @escaping (Result, Update) throws -> Result
    ) -> Promise<(Result, Success)>
  {
    var locking = makeLocking(isFair: true)
    var partialResult = initialResult
    let queue = Queue<Event>()

    let promise = Promise<(Result, Success)>()
    let handler = self.makeHandler(executor: .immediate) { (event, originalExecutor) in
      locking.lock()
      queue.push(event)
      locking.unlock()

      executor.execute(from: originalExecutor) {
        [weak promise] (originalExecutor) in
        guard case .some = promise else { return }

        let completion: Fallible<(Result, Success)>? = locking.locker {
          let event = queue.pop()!
          switch event {
          case let .update(update):
            do {
              partialResult = try nextPartialResult(partialResult, update)
              return nil
            } catch {
              return .failure(error)
            }
          case .completion(.success(let successValue)):
            let success: (Result, Success) = (partialResult, successValue)
            return .success(success)
          case let .completion(.failure(failure)):
            return .failure(failure)
          }
        }

        if let completion = completion, let promise = promise {
          promise.complete(completion)
        }
      }
    }

    promise._asyncNinja_retainHandlerUntilFinalization(handler)
    cancellationToken?.add(cancellable: promise)

    return promise
  }

  /// Returns future of the result of calling the given combining closure
  /// with each update value of this channel and an accumulating value.
  ///
  /// - Parameters:
  ///   - initialResult: the initial accumulating value.
  ///   - context: `ExectionContext` to call accumulation closure on
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - executor: to execute call predicate on accumulation closure on
  ///   - cancellationToken: CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - nextPartialResult: A closure that combines an accumulating
  ///     value and a update value of the channel into a new accumulating
  ///     value, to be used in the next call of the `nextPartialResult`
  ///     closure or returned to the caller.
  /// - Returns: The future tuple of accumulated completion and success of channel.
  func reduce<Result, C: ExecutionContext>(
    _ initialResult: Result,
    context: C,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    _ nextPartialResult: @escaping (C, Result, Update) throws -> Result
    ) -> Future<(Result, Success)>
  {

    // Test: EventSource_ToFutureTests.testReduceContextual

    let _executor = executor ?? context.executor
    let promise = _reduce(initialResult, executor: _executor, cancellationToken: cancellationToken) {
      [weak context] (accumulator, value) -> Result in
      guard let context = context
        else { throw AsyncNinjaError.contextDeallocated }

      return try nextPartialResult(context, accumulator, value)
    }

    context.addDependent(completable: promise)

    return promise
  }

  /// Returns future of the result of calling the given combining closure
  /// with each update value of this channel and an accumulating value.
  ///
  /// - Parameters:
  ///   - initialResult: the initial accumulating value.
  ///   - executor: to execute call accumulation closure on
  ///   - cancellationToken: CancellationToken` to use. Keep default value of the argument unless you need an extended cancellation options of returned channel
  ///   - nextPartialResult: A closure that combines an accumulating
  ///     value and a update value of the channel into a new accumulating
  ///     value, to be used in the next call of the `nextPartialResult` closure or returned to the caller.
  /// - Returns: The future tuple of accumulated completion and success of channel.
  func reduce<Result>(
    _ initialResult: Result,
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    _ nextPartialResult: @escaping (Result, Update) throws -> Result
    ) -> Future<(Result, Success)>
  {
    // Test: EventSource_ToFutureTests.testReduce
    return _reduce(initialResult, executor: executor, cancellationToken: cancellationToken, nextPartialResult)
  }
}
