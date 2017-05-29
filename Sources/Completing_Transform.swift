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

// MARK: - internal transforms

extension Completing {

  /// **internal use only**
  func _mapCompletion<T>(
    executor: Executor,
    pure: Bool,
    lazy: Bool,
    cancellationToken: CancellationToken?,
    _ transform: @escaping (_ completion: Fallible<Success>) throws -> T
    ) -> Promise<T> {
    return Promise<T>(lazy: lazy, cancellationToken: cancellationToken) { (promise) in
      let handler = self.makeCompletionHandler(executor: executor
      ) { [weak promise] (completion, originalExecutor) in
        if pure, case .none = promise { return }
        let transformedValue = fallible { try transform(completion) }
        promise?.complete(transformedValue, from: originalExecutor)
      }
      if pure {
        promise._asyncNinja_retainHandlerUntilFinalization(handler)
      } else {
        self._asyncNinja_retainHandlerUntilFinalization(handler)
      }
    }
  }

  /// **internal use only**
  func _mapCompletion<T, Context: ExecutionContext>(
    context: Context,
    executor: Executor?,
    pure: Bool,
    lazy: Bool,
    cancellationToken: CancellationToken?,
    _ transform: @escaping (_ strongContext: Context, _ completion: Fallible<Success>) throws -> T
    ) -> Promise<T> {
    return Promise<T>(
      context: context,
      lazy: lazy,
      cancellationToken: cancellationToken
    ) { (context: Context, promise: Promise<T>) in
      let handler = self.makeCompletionHandler(
        executor: executor ?? context.executor
      ) { [weak promise, weak context] (completion, originalExecutor) in
        if pure, case .none = promise { return }
        let transformedValue: Fallible<T> = fallible {
          if let context = context {
            return try transform(context, completion)
          } else {
            throw AsyncNinjaError.contextDeallocated
          }
        }
        promise?.complete(transformedValue, from: originalExecutor)
      }

      context.addDependent(completable: promise)
      if pure {
        promise._asyncNinja_retainHandlerUntilFinalization(handler)
      } else {
        self._asyncNinja_retainHandlerUntilFinalization(handler)
      }
    }
  }

  /// **internal use only**
  func _flatRecover<T: Completing>(
    executor: Executor,
    pure: Bool,
    lazy: Bool,
    cancellationToken: CancellationToken?,
    _ transform: @escaping (_ failure: Swift.Error) throws -> T
    ) -> Promise<Success> where T.Success == Success {
    return Promise<Success>(lazy: lazy, cancellationToken: cancellationToken) { (promise) in
      let handler = self.makeCompletionHandler(
        executor: executor
      ) { [weak promise] (completion, originalExecutor) -> Void in
        if pure, case .none = promise { return }

        switch completion {
        case let .success(success):
          promise?.succeed(success, from: originalExecutor)
        case let .failure(failure):
          do {
            promise?.complete(with: try transform(failure))
          } catch {
            promise?.fail(error, from: originalExecutor)
          }
        }
      }
      if pure {
        promise._asyncNinja_retainHandlerUntilFinalization(handler)
      } else {
        self._asyncNinja_retainHandlerUntilFinalization(handler)
      }
    }
  }

  /// **internal use only**
  func _flatRecover<T: Completing, Context: ExecutionContext>(
    context: Context,
    executor: Executor?,
    pure: Bool,
    lazy: Bool,
    cancellationToken: CancellationToken?,
    _ transform: @escaping (_ strongContext: Context, _ failure: Swift.Error) throws -> T
    ) -> Promise<Success> where T.Success == Success {
    return Promise<Success>(context: context, lazy: lazy, cancellationToken: cancellationToken) { (context, promise) in
      let handler = self.makeCompletionHandler(
        executor: executor ?? context.executor
      ) { [weak context, weak promise] (completion, originalExecutor) -> Void in
        if pure, case .none = promise { return }

        switch completion {
        case let .success(success):
          promise?.succeed(success, from: originalExecutor)
        case let .failure(failure):
          do {
            guard let context = context else {
              throw AsyncNinjaError.contextDeallocated
            }
            promise?.complete(with: try transform(context, failure))
          } catch {
            promise?.fail(error, from: originalExecutor)
          }
        }
      }

      context.addDependent(completable: promise)
      if pure {
        promise._asyncNinja_retainHandlerUntilFinalization(handler)
      } else {
        self._asyncNinja_retainHandlerUntilFinalization(handler)
      }
    }
  }
}

// MARK: - public transforms

public extension Completing {

  /// Transforms the `Completing` to a `Future` with transformation `(Fallible<Success>) -> T`.
  ///
  /// - Parameters:
  ///   - executor: to perform transform on
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - completion: of the `Completing`
  /// - Returns: `Future` that will complete with transformed value
  func mapCompletion<T>(
    executor: Executor = .primary,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (_ completion: Fallible<Success>) throws -> T
    ) -> Future<T> {
    return _mapCompletion(
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken,
      transform)
  }

  /// Transforms the `Completing` to a `Future` with transformation `(Fallible<Success>) -> Completing`.
  ///
  /// - Parameters:
  ///   - executor: to perform transform on
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - completion: of the `Completing`
  /// - Returns: `Future` that will complete with completion of returned `Completing`
  func flatMapCompletion<T: Completing>(
    executor: Executor = .primary,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (_ completion: Fallible<Success>) throws -> T
    ) -> Future<T.Success> {
    return mapCompletion(
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken,
      transform).flatten()
  }

  /// Transforms the `Completing` to a `Channel` with transformation `(Fallible<Success>) -> Completing&Updating`.
  ///
  /// - Parameters:
  ///   - executor: to perform transform on
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - completion: of the `Completing`
  /// - Returns: `Channel` that will complete with completion of returned `Completing&Updating`
  func flatMapCompletion<T: Completing&Updating>(
    executor: Executor = .primary,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (_ completion: Fallible<Success>) throws -> T
    ) -> Channel<T.Update, T.Success> {
    return mapCompletion(
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken,
      transform).flatten()
  }

  /// Transforms the `Completing` to a `Future` with transformation `(Success) -> T`.
  /// Failure of the `Completing` will be the fail of the returned `Future`.
  ///
  /// - Parameters:
  ///   - executor: to perform transform on
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - success: of the `Completing`
  /// - Returns: `Future` that will complete with transformed value
  func mapSuccess<T>(
    executor: Executor = .primary,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (_ success: Success) throws -> T
    ) -> Future<T> {
    return mapCompletion(
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken
    ) {
      try transform(try $0.liftSuccess())
    }
  }

  /// Transforms the `Completing` to a `Future` with transformation `(Success) -> Completing`.
  /// Failure of the `Completing` will be the fail of the returned `Future`.
  ///
  /// - Parameters:
  ///   - executor: to perform transform on
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - success: of the `Completing`
  /// - Returns: `Future` that will complete with completion of returned `Completing`
  func flatMapSuccess<T: Completing>(
    executor: Executor = .primary,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (_ success: Success) throws -> T
    ) -> Future<T.Success> {
    return mapSuccess(
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken,
      transform).flatten()
  }

  /// Transforms the `Completing` to a `Channel` with transformation `(Success) -> Completing&Updating`.
  /// Failure of the `Completing` will be the fail of the returned `Channel`.
  ///
  /// - Parameters:
  ///   - executor: to perform transform on
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - success: of the `Completing`
  /// - Returns: `Channel` that will complete with completion of returned `Completing&Updating`
  func flatMapSuccess<T: Completing&Updating>(
    executor: Executor = .primary,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (_ success: Success) throws -> T
    ) -> Channel<T.Update, T.Success> {
    return mapSuccess(
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken,
      transform).flatten()
  }

  /// Recovers from all failures with specified success.
  /// Success of the `Completing` will be the success of the returned `Future`.
  ///
  /// - Parameter success: to recover with.
  /// - Returns: `Future` that will always succeed
  func recover(with success: Success) -> Future<Success> {
    return recover(executor: .immediate) { _ in success }
  }

  /// Recovers from errors equal to a specified error with specified success.
  ///
  /// - Parameters:
  ///   - specificError: error to recover from
  ///   - success: to recover with.
  /// - Returns: `Future` that will
  ///   - succeed when the `Completing` succeeds
  ///   - or if failure of the `Compleing` is equal to the specified error will succeed with specified success
  ///   - or will fail with a failure of `Completing`
  func recover<E: Swift.Error>(
    from specificError: E,
    with success: Success
    ) -> Future<Success> where E: Equatable {
    return recover(executor: .immediate) {
      if let myError = $0 as? E,
        myError == specificError {
        return success
      } else {
        throw $0
      }
    }
  }

  /// Transforms the `Completing` to a `Future` with transformation `(Error) -> Success`.
  /// Success of the `Completing` will be the success of the returned `Future`.
  ///
  /// - Parameters:
  ///   - executor: to perform transform on
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - failure: of the `Completing`
  /// - Returns: `Future` that will complete with transformed value
  func recover(
    executor: Executor = .primary,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (_ failure: Swift.Error) throws -> Success
    ) -> Future<Success> {
    return mapCompletion(
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken
    ) {
      switch $0 {
      case .success(let success): return success
      case .failure(let failure): return try transform(failure)
      }
    }
  }

  /// Transforms the `Completing` to a `Future` with transformation `(E) -> Success`.
  /// Success of the `Completing` will be the success of the returned `Future`.
  ///
  /// - Parameters:
  ///   - executor: to perform transform on
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - failure: of the `Completing`
  /// - Returns: `Future` that will complete with transformed value
  func recover<E: Swift.Error>(
    from specificError: E,
    executor: Executor = .primary,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (_ failure: E) throws -> Success
    ) -> Future<Success> where E: Equatable {
    return recover(
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken
    ) {
      if let myError = $0 as? E, myError == specificError {
        return try transform(myError)
      } else {
        throw $0
      }
    }
  }

  /// Transforms the `Completing` to a `Future` with transformation `(E) -> Completing`.
  /// Success of the `Completing` will be the success of the returned `Future`.
  ///
  /// - Parameters:
  ///   - executor: to perform transform on
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - failure: of the `Completing`
  /// - Returns: `Future` that will complete with transformed value
  func flatRecover<T: Completing>(
    executor: Executor = .primary,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (_ failure: Swift.Error) throws -> T
    ) -> Future<Success> where T.Success == Success {
    return _flatRecover(
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken,
      transform)
  }

  /// Transforms the `Completing` to a `Future` with transformation `(E) -> Completing`.
  /// Success of the `Completing` will be the success of the returned `Future`.
  ///
  /// - Parameters:
  ///   - specificError: error to recover from
  ///   - executor: to perform transform on
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - failure: of the `Completing`
  /// - Returns: `Future` that will complete with transformed value
  func flatRecover<T: Completing, E: Swift.Error>(
    from specificError: E,
    executor: Executor = .primary,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (_ failure: E) throws -> T
    ) -> Future<Success> where T.Success == Success, E: Equatable {
    return flatRecover(
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken
    ) { (error: Swift.Error) -> T in
      guard let myError = error as? E, myError == specificError
        else { throw error }
      return try transform(myError)
    }
  }
}

// MARK: - public contextual transforms

public extension Completing {

  /// Transforms the `Completing` to a `Future` with transformation `(Fallible<Success>) -> T`.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - completion: of the `Completing`
  /// - Returns: `Future` that will complete with transformed value
  func mapCompletion<Transformed, Context: ExecutionContext>(
    context: Context,
    executor: Executor? = nil,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (Context, Fallible<Success>) throws -> Transformed
    ) -> Future<Transformed> {
    return _mapCompletion(
      context: context,
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken,
      transform)
  }

  /// Transforms the `Completing` to a `Future` with transformation `(Fallible<Success>) -> Completing`.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - completion: of the `Completing`
  /// - Returns: `Future` that will complete with completion of returned `Completing`
  func flatMapCompletion<T: Completing, Context: ExecutionContext>(
    context: Context,
    executor: Executor? = nil,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (Context, Fallible<Success>) throws -> T
    ) -> Future<T.Success> {
    return _mapCompletion(
      context: context,
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken,
      transform).flatten()
  }

  /// Transforms the `Completing` to a `Channel` with transformation `(Fallible<Success>) -> Completing&Updating`.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - completion: of the `Completing`
  /// - Returns: `Channel` that will complete with completion of returned `Completing&Updating`
  func flatMapCompletion<T: Completing&Updating, Context: ExecutionContext>(
    context: Context,
    executor: Executor? = nil,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (Context, Fallible<Success>) throws -> T
    ) -> Channel<T.Update, T.Success> {
    return _mapCompletion(
      context: context,
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken,
      transform).flatten()
  }

  /// Transforms the `Completing` to a `Future` with transformation `(Success) -> T`.
  /// Failure of the `Completing` will be the fail of the returned `Future`.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - success: of the `Completing`
  /// - Returns: `Future` that will complete with transformed value
  func mapSuccess<Transformed, Context: ExecutionContext>(
    context: Context,
    executor: Executor? = nil,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (Context, Success) throws -> Transformed
    ) -> Future<Transformed> {
    return _mapCompletion(
      context: context,
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken
    ) { (context, completion) -> Transformed in
      let success = try completion.liftSuccess()
      return try transform(context, success)
    }
  }

  /// Transforms the `Completing` to a `Future` with transformation `(Success) -> Completing`.
  /// Failure of the `Completing` will be the fail of the returned `Future`.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - success: of the `Completing`
  /// - Returns: `Future` that will complete with completion of returned `Completing`
  func flatMapSuccess<T: Completing, Context: ExecutionContext>(
    context: Context,
    executor: Executor? = nil,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (Context, Success) throws -> T
    ) -> Future<T.Success> {
    return mapSuccess(
      context: context,
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken,
      transform).flatten()
  }

  /// Transforms the `Completing` to a `Channel` with transformation `(Success) -> Completing&Updating`.
  /// Failure of the `Completing` will be the fail of the returned `Channel`.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - success: of the `Completing`
  /// - Returns: `Channel` that will complete with completion of returned `Completing&Updating`
  func flatMapSuccess<T: Completing&Updating, Context: ExecutionContext>(
    context: Context,
    executor: Executor? = nil,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (Context, Success) throws -> T
    ) -> Channel<T.Update, T.Success> {
    return mapSuccess(
      context: context,
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken,
      transform).flatten()
  }

  /// Transforms the `Completing` to a `Future` with transformation `(Error) -> Success`.
  /// Success of the `Completing` will be the success of the returned `Future`.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - failure: of the `Completing`
  /// - Returns: `Future` that will complete with transformed value
  func recover<Context: ExecutionContext>(
    context: Context,
    executor: Executor? = nil,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (Context, Swift.Error) throws -> Success
    ) -> Future<Success> {
    return mapCompletion(
      context: context,
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken
    ) { (context, completion) -> Success in
      switch completion {
      case .success(let success):
        return success
      case .failure(let failure):
        return try transform(context, failure)
      }
    }
  }

  /// Transforms the `Completing` to a `Future` with transformation `(E) -> Success`.
  /// Success of the `Completing` will be the success of the returned `Future`.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - failure: of the `Completing`
  /// - Returns: `Future` that will complete with transformed value
  func recover<E: Swift.Error, Context: ExecutionContext>(
    from specificError: E,
    context: Context,
    executor: Executor? = nil,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (Context, E) throws -> Success
    ) -> Future<Success> where E: Equatable {
    return recover(
      context: context,
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken
    ) { (context, error) in
      if let myError = error as? E, myError == specificError {
        return try transform(context, myError)
      } else {
        throw error
      }
    }
  }

  /// Transforms the `Completing` to a `Future` with transformation `(E) -> Completing`.
  /// Success of the `Completing` will be the success of the returned `Future`.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - failure: of the `Completing`
  /// - Returns: `Future` that will complete with transformed value
  func flatRecover<T: Completing, Context: ExecutionContext>(
    context: Context,
    executor: Executor? = nil,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (Context, Swift.Error) throws -> T
    ) -> Future<Success> where T.Success == Success {
    return _flatRecover(
      context: context,
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken,
      transform)
  }

  /// Transforms the `Completing` to a `Future` with transformation `(E) -> Completing`.
  /// Success of the `Completing` will be the success of the returned `Future`.
  ///
  /// - Parameters:
  ///   - specificError: error to recover from
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - pure: defines if the transfromation is pure.
  ///     Pure transformations have no side effects:
  ///     - do not change shared state
  ///     - do not write data on disk
  ///     - ...
  ///
  ///     Transformations with side effects are impure.
  ///   - transform: transformation to perform
  ///   - failure: of the `Completing`
  /// - Returns: `Future` that will complete with transformed value
  func flatRecover<T: Completing, E: Swift.Error, Context: ExecutionContext>(
    from specificError: E,
    context: Context,
    executor: Executor? = nil,
    pure: Bool = AsyncNinjaConstants.isFuturesPureByDefault,
    lazy: Bool = AsyncNinjaConstants.isFuturesLazyByDefault,
    cancellationToken: CancellationToken? = nil,
    _ transform: @escaping (Context, Swift.Error) throws -> T
    ) -> Future<Success> where T.Success == Success, E: Equatable {
    return flatRecover(
      context: context,
      executor: executor,
      pure: pure,
      lazy: lazy,
      cancellationToken: cancellationToken
    ) { (context, error) -> T in
      guard let myError = error as? E, myError == specificError
        else { throw error }
      return try transform(context, myError)
    }
  }
}

// MARK: - delayed

public extension Completing {

  /// Returns future that completes after a timeout after completion of self
  func delayedCompletion(
    timeout: Double,
    on executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil
    ) -> Future<Success> {
    let promise = Promise<Success>()
    let handler = makeCompletionHandler(
      executor: .immediate
    ) { [weak promise] (completion, _) in
      executor.execute(after: timeout) { [weak promise] executor in
        guard let promise = promise else { return }
        promise.complete(completion, from: executor)
      }
    }
    promise._asyncNinja_retainHandlerUntilFinalization(handler)
    cancellationToken?.add(cancellable: promise)
    return promise
  }
}

// MARK: - Flattening

public extension Future where S: Completing {
  /// Flattens two nested futures
  ///
  /// - Returns: flattened future
  func flatten() -> Future<S.Success> {
    // Test: FutureTests.testFlatten
    // Test: FutureTests.testFlatten_OuterFailure
    // Test: FutureTests.testFlatten_InnerFailure
    let promise = Promise<S.Success>()
    let handler = makeCompletionHandler(
      executor: .immediate
    ) { [weak promise] (failure, originalExecutor) in
      guard let promise = promise else { return }
      switch failure {
      case .success(let future):
        let handler = future.makeCompletionHandler(
          executor: .immediate
        ) { [weak promise] (completion, originalExecutor) -> Void in
          promise?.complete(completion, from: originalExecutor)
        }
        promise._asyncNinja_retainHandlerUntilFinalization(handler)
      case .failure(let error):
        promise.fail(error, from: originalExecutor)
      }
    }

    promise._asyncNinja_retainHandlerUntilFinalization(handler)

    return promise
  }
}

public extension Future where S: Completing, S: Updating {
  /// Flattens channel nested in future
  ///
  /// - Returns: flattened future
  func flatten() -> Channel<S.Update, S.Success> {
    // Test: FutureTests.testChannelFlatten
    let producer = Producer<S.Update, S.Success>()

    let handler = makeCompletionHandler(
      executor: .immediate
    ) { [weak producer] (failure, originalExecutor) in
      guard let producer = producer else { return }
      switch failure {
      case .success(let channel):
        let completionHandler = channel.makeCompletionHandler(
          executor: .immediate
        ) { [weak producer] (completion, originalExecutor) -> Void in
          producer?.complete(completion, from: originalExecutor)
        }
        producer._asyncNinja_retainHandlerUntilFinalization(completionHandler)

        let updateHandler = channel.makeUpdateHandler(
          executor: .immediate
        ) { [weak producer] (update, originalExecutor) -> Void in
          producer?.update(update, from: originalExecutor)
        }
        producer._asyncNinja_retainHandlerUntilFinalization(updateHandler)
      case .failure(let error):
        producer.fail(error, from: originalExecutor)
      }
    }

    producer._asyncNinja_retainHandlerUntilFinalization(handler)

    return producer
  }
}
