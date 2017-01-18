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

public extension Channel {

  /// **internal use only**
  private func _first(executor: Executor,
                      cancellationToken: CancellationToken?,
                      `where` predicate: @escaping(PeriodicValue) throws -> Bool
    ) -> Promise<PeriodicValue?> {

    let promise = Promise<PeriodicValue?>()
    let executor_ = executor.makeDerivedSerialExecutor()
    let handler = self.makeHandler(executor: executor_) {
      [weak promise] in
      switch $0 {
      case let .periodic(periodicValue):
        do {
          if try predicate(periodicValue) {
            promise?.succeed(with: periodicValue)
          }
        } catch {
          promise?.fail(with: error)
        }
      case .final(.success):
        promise?.succeed(with: nil)
      case let .final(.failure(failureValue)):
        promise?.fail(with: failureValue)
      }
    }

    promise.insertHandlerToReleasePool(handler)
    cancellationToken?.add(cancellable: promise)

    return promise
  }

  /// Returns future of first periodic value matching predicate
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need
  ///     to override an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - predicate: returns true if periodic value matches
  ///     and returned future may be completed with it
  /// - Returns: future
  func first<C: ExecutionContext>(context: C,
             executor: Executor? = nil,
             cancellationToken: CancellationToken? = nil,
             `where` predicate: @escaping(C, PeriodicValue) throws -> Bool
    ) -> Future<PeriodicValue?> {
    let executor_ = executor ?? context.executor
    let promise = self._first(executor: executor_, cancellationToken: cancellationToken) {
      [weak context] (periodicValue) -> Bool in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try predicate(context, periodicValue)
    }

    context.addDependent(finite: promise)

    return promise
  }

  /// Returns future of first periodic value matching predicate
  ///
  /// - Parameters:
  ///   - executor: to execute call predicate on
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - predicate: returns true if periodic value matches
  ///     and returned future may be completed with it
  /// - Returns: future
  func first(executor: Executor = .immediate,
             cancellationToken: CancellationToken? = nil,
             `where` predicate: @escaping(PeriodicValue) throws -> Bool
    ) -> Future<PeriodicValue?> {
    return _first(executor: executor,
                  cancellationToken: cancellationToken,
                  where: predicate)
  }
}

// MARK: - channel last(where:)

public extension Channel {

  /// **internal use only**
  private func _last(executor: Executor,
                     cancellationToken: CancellationToken?,
                     `where` predicate: @escaping(PeriodicValue) throws -> Bool
    ) -> Promise<PeriodicValue?> {

    var latestMatchingPeriodic: PeriodicValue?

    let promise = Promise<PeriodicValue?>()
    let executor_ = executor.makeDerivedSerialExecutor()
    let handler = self.makeHandler(executor: executor_) { [weak promise] in
      switch $0 {
      case let .periodic(periodicValue):
        do {
          if try predicate(periodicValue) {
            latestMatchingPeriodic = periodicValue
          }
        } catch {
          promise?.fail(with: error)
        }
      case .final(.success):
        promise?.succeed(with: latestMatchingPeriodic)
      case let .final(.failure(failureValue)):
        if let latestMatchingPeriodic = latestMatchingPeriodic {
          promise?.succeed(with: latestMatchingPeriodic)
        } else {
          promise?.fail(with: failureValue)
        }
      }
    }

    promise.insertHandlerToReleasePool(handler)
    cancellationToken?.add(cancellable: promise)

    return promise
  }

  /// Returns future of last periodic value matching predicate
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor. Keep default value of the argument unless you need to override an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use. Keep default value of the argument unless you need an extended cancellation options of returned channel
  ///   - predicate: returns true if periodic value matches and returned future may be completed with it
  /// - Returns: future
  func last<C: ExecutionContext>(context: C,
            executor: Executor? = nil,
            cancellationToken: CancellationToken? = nil,
            `where` predicate: @escaping(C, PeriodicValue) throws -> Bool
    ) -> Future<PeriodicValue?> {
    let _executor = executor ?? context.executor
    let promise = self._last(executor: _executor,
                             cancellationToken: cancellationToken)
    {
      [weak context] (periodicValue) -> Bool in
      guard let context = context else {
        throw AsyncNinjaError.contextDeallocated
      }
      return try predicate(context, periodicValue)
    }

    context.addDependent(finite: promise)

    return promise
  }

  /// Returns future of last periodic value matching predicate
  ///
  /// - Parameters:
  ///   - executor: to execute call predicate on
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - predicate: returns true if periodic value matches
  ///     and returned future may be completed with it
  /// - Returns: future
  func last(executor: Executor = .immediate,
            cancellationToken: CancellationToken? = nil,
            `where` predicate: @escaping(PeriodicValue) throws -> Bool
    ) -> Future<PeriodicValue?> {
    return _last(executor: executor,
                 cancellationToken: cancellationToken,
                 where: predicate)
  }
}

// MARK: - channel reduce

public extension Channel {

  /// **internal use only**
  private func _reduce<Result>(_ initialResult: Result,
              executor: Executor = .immediate,
              cancellationToken: CancellationToken? = nil,
              _ nextPartialResult: @escaping (Result, PeriodicValue) throws -> Result
    ) -> Promise<(Result, FinalValue)> {
    var result = initialResult
    let _executor = executor.makeDerivedSerialExecutor()
    let promise = Promise<(Result, FinalValue)>()
    let handler = self.makeHandler(executor: _executor) { [weak promise] in
      switch $0 {
      case let .periodic(periodicValue):
        do {
          result = try nextPartialResult(result, periodicValue)
        } catch {
          promise?.fail(with: error)
        }
      case .final(.success(let successValue)):
        promise?.succeed(with: (result, successValue))
      case let .final(.failure(failureValue)):
        promise?.fail(with: failureValue)
      }
    }

    promise.insertHandlerToReleasePool(handler)
    cancellationToken?.add(cancellable: promise)

    return promise
  }

  /// Returns future of the result of calling the given combining closure
  /// with each periodic value of this channel and an accumulating value.
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
  ///     value and a periodic value of the channel into a new accumulating
  ///     value, to be used in the next call of the `nextPartialResult`
  ///     closure or returned to the caller.
  /// - Returns: The future tuple of final accumulated value and success value of channel.
  func reduce<Result, C: ExecutionContext>(_ initialResult: Result, context: C,
              executor: Executor? = nil,
              cancellationToken: CancellationToken? = nil,
              _ nextPartialResult: @escaping (C, Result, PeriodicValue) throws -> Result
    ) -> Future<(Result, FinalValue)> {
    let _executor = executor ?? context.executor
    let promise = _reduce(initialResult, executor: _executor, cancellationToken: cancellationToken) {
      [weak context] (accumulator, value) -> Result in
      guard let context = context else {
        throw AsyncNinjaError.contextDeallocated
      }

      return try nextPartialResult(context, accumulator, value)
    }

    context.addDependent(finite: promise)

    return promise
  }

  /// Returns future of the result of calling the given combining closure
  /// with each periodic value of this channel and an accumulating value.
  ///
  /// - Parameters:
  ///   - initialResult: the initial accumulating value.
  ///   - executor: to execute call accumulation closure on
  ///   - cancellationToken: CancellationToken` to use. Keep default value of the argument unless you need an extended cancellation options of returned channel
  ///   - nextPartialResult: A closure that combines an accumulating
  ///     value and a periodic value of the channel into a new accumulating
  ///     value, to be used in the next call of the `nextPartialResult` closure or returned to the caller.
  /// - Returns: The future tuple of final accumulated value and success value of channel.
  func reduce<Result>(_ initialResult: Result,
              executor: Executor = .immediate,
              cancellationToken: CancellationToken? = nil,
              _ nextPartialResult: @escaping (Result, PeriodicValue) throws -> Result
    ) -> Future<(Result, FinalValue)> {
    return _reduce(initialResult, executor: executor, cancellationToken: cancellationToken, nextPartialResult)
  }
}
