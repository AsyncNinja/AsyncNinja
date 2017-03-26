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

// MARK: - channel first(where:)

public extension EventSource {

  /// **internal use only**
  private func _first(executor: Executor,
                      cancellationToken: CancellationToken?,
                      `where` predicate: @escaping(Update) throws -> Bool
    ) -> Promise<Update?> {

    let promise = Promise<Update?>()
    let handler = self.makeHandler(executor: executor) {
      [weak promise] (event, originalExecutor) in
      switch event {
      case let .update(update):
        do {
          if try predicate(update) {
            promise?.succeed(update, from: originalExecutor)
          }
        } catch {
          promise?.fail(error, from: originalExecutor)
        }
      case .completion(.success):
        promise?.succeed(nil, from: originalExecutor)
      case let .completion(.failure(failure)):
        promise?.fail(failure, from: originalExecutor)
      }
    }

    promise._asyncNinja_retainHandlerUntilFinalization(handler)
    cancellationToken?.add(cancellable: promise)

    return promise
  }

  /// Returns future of first update value matching predicate
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need
  ///     to override an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - predicate: returns true if update value matches
  ///     and returned future may be completed with it
  /// - Returns: future
  func first<C: ExecutionContext>(context: C,
             executor: Executor? = nil,
             cancellationToken: CancellationToken? = nil,
             `where` predicate: @escaping(C, Update) throws -> Bool
    ) -> Future<Update?> {

    // Test: EventSource_ToFutureTests.testFirstSuccessIncompleteContextual
    // Test: EventSource_ToFutureTests.testFirstNotFoundContextual
    // Test: EventSource_ToFutureTests.testFirstFailureContextual

    let executor_ = executor ?? context.executor
    let promise = self._first(executor: executor_, cancellationToken: cancellationToken) {
      [weak context] (update) -> Bool in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try predicate(context, update)
    }

    context.addDependent(completable: promise)

    return promise
  }

  /// Returns future of first update value matching predicate
  ///
  /// - Parameters:
  ///   - executor: to execute call predicate on
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - predicate: returns true if update value matches
  ///     and returned future may be completed with it
  /// - Returns: future
  func first(executor: Executor = .immediate,
             cancellationToken: CancellationToken? = nil,
             `where` predicate: @escaping(Update) throws -> Bool
    ) -> Future<Update?> {

    // Test: EventSource_ToFutureTests.testFirstSuccessIncomplete
    // Test: EventSource_ToFutureTests.testFirstNotFound
    // Test: EventSource_ToFutureTests.testFirstFailure

    return _first(executor: executor,
                  cancellationToken: cancellationToken,
                  where: predicate)
  }
}

// MARK: - channel last(where:)

public extension EventSource {

  /// **internal use only**
  private func _last(executor: Executor,
                     cancellationToken: CancellationToken?,
                     `where` predicate: @escaping(Update) throws -> Bool
    ) -> Promise<Update?> {

    var latestMatchingUpdate: Update?
    var locking = makeLocking(isFair: true)

    let promise = Promise<Update?>()
    let handler = self.makeHandler(executor: executor) {
      [weak promise] (event, originalExecutor) in
      switch event {
      case let .update(update):
        do {
          if try predicate(update) {
            locking.lock()
            latestMatchingUpdate = update
            locking.unlock()
          }
        } catch {
          promise?.fail(error, from: originalExecutor)
        }
      case .completion(.success):
        let success = locking.locker { latestMatchingUpdate }
        promise?.succeed(success, from: originalExecutor)
      case let .completion(.failure(failure)):
        if let success = locking.locker({ latestMatchingUpdate }) {
          promise?.succeed(success, from: originalExecutor)
        } else {
          promise?.fail(failure, from: originalExecutor)
        }
      }
    }

    promise._asyncNinja_retainHandlerUntilFinalization(handler)
    cancellationToken?.add(cancellable: promise)

    return promise
  }

  /// Returns future of last update value matching predicate
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor. Keep default value of the argument unless you need to override an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use. Keep default value of the argument unless you need an extended cancellation options of returned channel
  ///   - predicate: returns true if update value matches and returned future may be completed with it
  /// - Returns: future
  func last<C: ExecutionContext>(context: C,
            executor: Executor? = nil,
            cancellationToken: CancellationToken? = nil,
            `where` predicate: @escaping(C, Update) throws -> Bool
    ) -> Future<Update?> {

    // Test: EventSource_ToFutureTests.testLastSuccessIncompleteContextual
    // Test: EventSource_ToFutureTests.testLastNotFoundContextual
    // Test: EventSource_ToFutureTests.testLastFailureContextual

    let _executor = executor ?? context.executor
    let promise = self._last(executor: _executor,
                             cancellationToken: cancellationToken)
    {
      [weak context] (update) -> Bool in
      guard let context = context else {
        throw AsyncNinjaError.contextDeallocated
      }
      return try predicate(context, update)
    }

    context.addDependent(completable: promise)

    return promise
  }

  /// Returns future of last update value matching predicate
  ///
  /// - Parameters:
  ///   - executor: to execute call predicate on
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - predicate: returns true if update value matches
  ///     and returned future may be completed with it
  /// - Returns: future
  func last(executor: Executor = .immediate,
            cancellationToken: CancellationToken? = nil,
            `where` predicate: @escaping(Update) throws -> Bool
    ) -> Future<Update?> {

    // Test: EventSource_ToFutureTests.testLastSuccessIncomplete
    // Test: EventSource_ToFutureTests.testLastNotFound
    // Test: EventSource_ToFutureTests.testLastFailure

    return _last(executor: executor,
                 cancellationToken: cancellationToken,
                 where: predicate)
  }
}
