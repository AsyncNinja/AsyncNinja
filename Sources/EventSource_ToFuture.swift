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
    var queue = Queue<ChannelEvent<Update, Success>>()
    var locking = makeLocking(isFair: true)
    var isComplete = false

    let handler = self.makeHandler(
      executor: .immediate
    ) { (event, originalExecutor) in
      let isCompleteLocal: Bool = locking.locker {
        if isComplete {
          return true
        } else {
          queue.push(event)
          return false
        }
      }

      guard !isCompleteLocal else { return }

      executor.execute(
        from: originalExecutor
      ) { [weak promise] (originalExecutor) in
        guard case .some = promise else { return }

        let completion: Fallible<Update?>? = locking.locker {
          guard !isComplete else { return nil }
          switch queue.pop()! {
          case let .update(update):
            do {
              if try predicate(update) {
                isComplete = true
                return .success(update)
              } else {
                return nil
              }
            } catch {
              return .failure(error)
            }
          case .completion(.success):
            return .success(nil)
          case let .completion(.failure(failure)):
            return .failure(failure)
          }
        }

        if let completion = completion {
          promise?.complete(completion, from: originalExecutor)
        }
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
  ///     an extended cancellation options of returned future
  ///   - predicate: returns true if update value matches
  ///     and returned future may be completed with it
  /// - Returns: future
  func first<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    `where` predicate: @escaping(C, Update) throws -> Bool
    ) -> Future<Update?> {

    // Test: EventSource_ToFutureTests.testFirstSuccessIncompleteContextual
    // Test: EventSource_ToFutureTests.testFirstNotFoundContextual
    // Test: EventSource_ToFutureTests.testFirstFailureContextual

    let executor_ = executor ?? context.executor
    let promise = self._first(
      executor: executor_,
      cancellationToken: cancellationToken
    ) { [weak context] (update) -> Bool in
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
  ///     an extended cancellation options of returned future
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
    var queue = Queue<ChannelEvent<Update, Success>>()
    let promise = Promise<Update?>()

    let handler = self.makeHandler(
      executor: .immediate
    ) { (event, originalExecutor) in
      locking.lock()
      queue.push(event)
      locking.unlock()

      executor.execute(
        from: originalExecutor
      ) { [weak promise] (originalExecutor) in
        guard case .some = promise else { return }
        let completion: Fallible<Update?>? = locking.locker {
          let event = queue.pop()!
          switch event {
          case let .update(update):
            do {
              if try predicate(update) {
                latestMatchingUpdate = update
              }
              return nil
            } catch { return .failure(error) }
          case .completion(.success):
            return .success(latestMatchingUpdate)
          case let .completion(.failure(failure)):
            if let success = latestMatchingUpdate {
              return .success(success)
            } else {
              return .failure(failure)
            }
          }
        }

        if let completion = completion {
          promise?.complete(completion, from: originalExecutor)
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
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need
  ///     to override an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - predicate: returns true if update value matches and returned future may be completed with it
  /// - Returns: future
  func last<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    `where` predicate: @escaping(C, Update) throws -> Bool
    ) -> Future<Update?> {

    // Test: EventSource_ToFutureTests.testLastSuccessIncompleteContextual
    // Test: EventSource_ToFutureTests.testLastNotFoundContextual
    // Test: EventSource_ToFutureTests.testLastFailureContextual

    let _executor = executor ?? context.executor
    let promise = self._last(
      executor: _executor,
      cancellationToken: cancellationToken
    ) { [weak context] (update) -> Bool in
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
  ///     an extended cancellation options of returned future
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

// MARK: - contains
public extension EventSource {
  /// Checks each update with predicate. Succeeds returned future with true
  /// on first found update that matches predicate. Succeeds retured future
  /// with false if no matching updates were found
  ///
  /// - Parameters:
  ///   - executor: to execute call predicate on
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned future
  ///   - predicate: returns true if update value matches
  ///     and returned future may be completed with it
  /// - Returns: future
  func contains(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    where predicate: @escaping (Update) -> Bool
    ) -> Future<Bool> {
    // Test: EventSource_ToFutureTests.testContainsTrue
    // Test: EventSource_ToFutureTests.testContainsFalse

    var locking = makeLocking(isFair: true)
    let promise = Promise<Bool>()
    let handler = makeHandler(
      executor: executor
    ) { [weak promise] (event, _) in
      if let promise = promise {
        if case .some = promise.completion {
          return
        }
      } else {
        return
      }

      let result: Bool? = locking.locker {
        switch event {
        case let .update(update):
          if predicate(update) { return true } else { return nil }
        case .completion:
          return false
        }
      }

      if let result = result {
        promise?.succeed(result)
      }
    }

    promise._asyncNinja_retainHandlerUntilFinalization(handler)
    cancellationToken?.add(cancellable: promise)
    return promise
  }
}

extension EventSource where Update: Equatable {
  /// Checks each EventSource for a specific falue. Succeeds returned
  /// future with true on first found update that is equal to the value.
  /// Succeeds retured future with false if no equal updates were found
  ///
  /// - Parameters:
  ///   - value: to check for equality with
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned future
  /// - Returns: future
  public func contains(
    _ value: Update,
    cancellationToken: CancellationToken? = nil
    ) -> Future<Bool> {
    // Test: EventSource_ToFutureTests.testContainsValueTrue
    // Test: EventSource_ToFutureTests.testContainsValueFalse
    return contains(executor: .immediate, cancellationToken: cancellationToken) { $0 == value }
  }
}
