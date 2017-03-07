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

public extension Completing {

  /// Shorthand property that returns true if `Completing` is complete
  var isComplete: Bool {
    switch self.completion {
    case .some: return true
    case .none: return false
    }
  }

  /// Shorthand property that returns success
  /// if `Completing` is completed with success or nil otherwise
  var success: Success? { return self.completion?.success }

  /// Shorthand property that returns failure value
  /// if `Completing` is completed with failure or nil otherwise
  var failure: Swift.Error? { return self.completion?.failure }
}

public extension Completing {
  /// Transforms Completing<SuccessA> => Completing<SuccessB>
  ///
  /// This method is suitable for **pure**ish transformations (not changing shared state).
  /// Use method mapCompletion(context:executor:transform:) for state changing transformations.
  func mapCompletion<Transformed>(
    executor: Executor = .primary,
    _ transform: @escaping (Fallible<Success>) throws -> Transformed
    ) -> Future<Transformed> {
    let promise = Promise<Transformed>()
    let handler = self.makeCompletionHandler(executor: executor) {
      [weak promise] (completion, originalExecutor) -> Void in
      guard case .some = promise else { return }
      let transformedValue = fallible { try transform(completion) }
      promise?.complete(transformedValue, from: originalExecutor)
    }
    promise._asyncNinja_insertHandlerToReleasePool(handler)
    return promise
  }

  /// Transforms Completing<SuccessA> => Future<SuccessB>. Flattens future returned by the transform
  ///
  /// This method is suitable for **pure**ish transformations (not changing shared state).
  /// Use method flatMapCompletion(context:executor:transform:) for state changing transformations.
  func flatMapCompletion<Transformed>(
    executor: Executor = .primary,
    _ transform: @escaping (Fallible<Success>) throws -> Future<Transformed>
    ) -> Future<Transformed> {
    return self.mapCompletion(executor: executor, transform).flatten()
  }

  /// Transforms Completing<SuccessA> => Future<SuccessB>
  ///
  /// This is the same as mapCompletion(executor:transform:)
  /// but does not perform transformation if this future fails.
  func mapSuccess<Transformed>(
    executor: Executor = .primary,
    _ transform: @escaping (Success) throws -> Transformed
    ) -> Future<Transformed> {
    return self.mapCompletion(executor: executor) { (value) -> Transformed in
      let transformedValue = try value.liftSuccess()
      return try transform(transformedValue)
    }
  }

  /// Transforms Completing<SuccessA> => Future<SuccessB>. Flattens future returned by the transform
  ///
  /// This is the same as flatMapCompletion(executor:transform:)
  /// but does not perform transformation if this future fails.
  func flatMapSuccess<Transformed>(
    executor: Executor = .primary,
    _ transform: @escaping (Success) throws -> Future<Transformed>
    ) -> Future<Transformed> {
    return self.mapSuccess(executor: executor, transform).flatten()
  }

  /// Recovers failure of this future if there is one
  func recover(with success: Success) -> Future<Success> {
    return self
      .recover(executor: .immediate) { _ in success }
  }

  /// Recovers failure of this future if there is one
  func recover<E: Swift.Error>(
    from specificError: E,
    with success: Success
    ) -> Future<Success> where E: Equatable
  {
    return self.recover(executor: .immediate) {
      if let myError = $0 as? E,
        myError == specificError {
        return success
      } else {
        throw $0
      }
    }
  }

  /// Recovers failure of this future if there is one
  func recover(
    executor: Executor = .primary,
    _ transform: @escaping (Swift.Error) throws -> Success
    ) -> Future<Success>
  {
    return self.mapCompletion(executor: executor) {
      (value) -> Success in
      switch value {
      case .success(let success): return success
      case .failure(let failure): return try transform(failure)
      }
    }
  }

  /// Recovers failure of this future if there is one
  func recover<E: Swift.Error>(
    from specificError: E,
    executor: Executor = .primary,
    _ transform: @escaping (E) throws -> Success
    ) -> Future<Success> where E: Equatable
  {
    return self.recover(executor: executor) {
      if let myError = $0 as? E, myError == specificError {
        return try transform(myError)
      } else {
        throw $0
      }
    }
  }
  
  /// Recovers failure of this future if there is one. Flattens future returned by the transform
  func flatRecover(
    executor: Executor = .primary,
    _ transform: @escaping (Swift.Error) throws -> Future<Success>
    ) -> Future<Success> {
    let promise = Promise<Success>()
    let handler = self.makeCompletionHandler(executor: executor) {
      [weak promise] (completion, originalExecutor) -> Void in
      guard case .some = promise else { return }
      
      switch completion {
      case let .success(success):
        promise?.succeed(success, from: originalExecutor)
      case let .failure(failure):
        do { promise?.complete(with: try transform(failure)) }
        catch { promise?.fail(error, from: originalExecutor) }
      }
    }
    promise._asyncNinja_insertHandlerToReleasePool(handler)
    return promise
  }
  
  /// Recovers failure of this future if there is one. Flattens future returned by the transform
  func flatRecover<E: Swift.Error>(
    from specificError: E,
    executor: Executor = .primary,
    _ transform: @escaping (E) throws -> Future<Success>
    ) -> Future<Success> where E: Equatable
  {
    return flatRecover(executor: executor) {
      if let myError = $0 as? E, myError == specificError {
        return try transform(myError)
      } else {
        throw $0
      }
    }
  }
}

public extension Completing {
  /// Transforms Completing<SuccessA> => Completing<SuccessB>
  ///
  /// This method is suitable for impure transformations (changing state of context).
  /// Use method mapCompletion(context:transform:) for pure -ish transformations.
  func mapCompletion<Transformed, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (C, Fallible<Success>) throws -> Transformed
    ) -> Future<Transformed> {
    return self.mapCompletion(executor: executor ?? context.executor) {
      [weak context] (value) -> Transformed in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, value)
    }
  }

  /// Transforms Comletable<SuccessA> => Future<SuccessB>. Flattens future returned by the transform
  ///
  /// This method is suitable for impure transformations (changing state of context).
  /// Use method flatMapCompletion(context:transform:) for pure -ish transformations.
  func flatMapCompletion<Transformed, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (C, Fallible<Success>) throws -> Future<Transformed>
    ) -> Future<Transformed> {
    return self.mapCompletion(context: context, executor: executor, transform).flatten()
  }

  /// Transforms Completing<SuccessA> => Future<SuccessB>
  ///
  /// This is the same as mapCompletion(context:executor:transform:)
  /// but does not perform transformation if this future fails.
  func mapSuccess<Transformed, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (C, Success) throws -> Transformed
    ) -> Future<Transformed> {
    return self.mapCompletion(context: context, executor: executor) {
      (context, value) -> Transformed in
      let success = try value.liftSuccess()
      return try transform(context, success)
    }
  }

  /// Transforms Completing<SuccessA> => Future<SuccessB>. Flattens future returned by the transform
  ///
  /// This is the same as flatMapCompletion(context:executor:transform:)
  /// but does not perform transformation if this future fails.
  func flatMapSuccess<Transformed, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (C, Success) throws -> Future<Transformed>
    ) -> Future<Transformed> {
    return self.mapSuccess(context: context, executor: executor, transform).flatten()
  }

  /// Recovers failure of this future if there is one with contextual transformer.
  func recover<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (C, Swift.Error) throws -> Success
    ) -> Future<Success> {
    return self.mapCompletion(context: context, executor: executor) {
      (context, value) -> Success in
      switch value {
      case .success(let success):
        return success
      case .failure(let failure):
        return try transform(context, failure)
      }
    }
  }

  /// Recovers failure of this future if there is one with contextual transformer.
  func recover<E: Swift.Error, C: ExecutionContext>(
    from specificError: E,
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (C, E) throws -> Success
    ) -> Future<Success> where E: Equatable
  {
    return self.recover(context: context, executor: executor) {
      (context, error) in
      if let myError = error as? E, myError == specificError {
        return try transform(context, myError)
      } else {
        throw error
      }
    }
  }
  
  /// Recovers failure of this future if there is one with contextual transformer.
  /// Flattens future returned by the transform
  func flatRecover<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (C, Swift.Error) throws -> Future<Success>
    ) -> Future<Success>
  {
    return self.flatRecover(executor: executor ?? context.executor) {
      [weak context] (failure) -> Future<Success> in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, failure)
    }
  }
  
  /// Recovers failure of this future if there is one with contextual transformer.
  /// Flattens future returned by the transform
  func flatRecover<E: Swift.Error, C: ExecutionContext>(
    from specificError: E,
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (C, Swift.Error) throws -> Future<Success>
    ) -> Future<Success> where E: Equatable
  {
    return self.flatRecover(context: context, executor: executor) {
      (context, error) in
      if let myError = error as? E, myError == specificError {
        return try transform(context, myError)
      } else {
        throw error
      }
    }
  }
}

public extension Completing {
  /// Performs block when completion value.
  /// *This method is method is less preferable then `onComplete(context: ...)`.*
  ///
  /// - Parameters:
  ///   - executor: to call block on
  ///   - block: block to call on completion
  func onComplete(
    executor: Executor = .primary,
    _ block: @escaping (Fallible<Success>) -> Void) {
    _onComplete(executor: executor) {
      (completion, originalExecutor) in
      block(completion)
    }
  }

  internal func _onComplete(
    executor: Executor = .primary,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void) {
    let handler = self.makeCompletionHandler(executor: executor) {
      (completion, originalExecutor) in
      block(completion, originalExecutor)
    }
    self._asyncNinja_insertHandlerToReleasePool(handler)
  }

  /// Performs block when competion becomes available.
  func onSuccess(
    executor: Executor = .primary,
    _ block: @escaping (Success) -> Void) {
    self.onComplete(executor: executor) { $0.onSuccess(block) }
  }

  /// Performs block when failure becomes available.
  func onFailure(
    executor: Executor = .primary,
    _ block: @escaping (Swift.Error) -> Void) {
    self.onComplete(executor: executor) { $0.onFailure(block) }
  }
}

public extension Completing {
  /// Performs block when completion value.
  /// This method is suitable for applying completion to context.
  ///
  /// - Parameters:
  ///   - context: to complete on
  ///   - executor: override of `ExecutionContext`s executor. Keep default value of the argument unless you need to override an executor provided by the context
  ///   - block: block to call on completion
  func onComplete<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ block: @escaping (C, Fallible<Success>) -> Void) {
    // Test: FutureTests.testOnCompleteContextual_ContextAlive
    // Test: FutureTests.testOnCompleteContextual_ContextDead
    _onComplete(context: context, executor: executor) {
      (context, completion, originalExecutor) in
      block(context, completion)
    }
  }

  internal func _onComplete<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ block: @escaping (_ context: C, _ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void) {
    // Test: FutureTests.testOnCompleteContextual_ContextAlive
    // Test: FutureTests.testOnCompleteContextual_ContextDead
    let handler = self.makeCompletionHandler(executor: executor ?? context.executor) {
      [weak context] (completion, originalExecutor) in
      guard let context = context else { return }
      block(context, completion, originalExecutor)
    }

    if let handler = handler {
      context.releaseOnDeinit(handler)
    }
  }

  /// Performs block when completion becomes available.
  func onSuccess<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ block: @escaping (C, Success) -> Void) {
    self.onComplete(context: context, executor: executor) {
      (context, completion) in
      if let success = completion.success {
        block(context, success)
      }
    }
  }

  /// Performs block when failure becomes available.
  func onFailure<C: ExecutionContext>(
    context: C, executor:
    Executor? = nil,
    _ block: @escaping (C, Swift.Error) -> Void) {
    self.onComplete(context: context, executor: executor) {
      (context, completion) in
      if let failure = completion.failure {
        block(context, failure)
      }
    }
  }
}

/// Each of these methods synchronously awaits for future to complete.
/// Using this method is **strongly** discouraged. Calling it on the same serial queue
/// as any code performed on the same queue this future depends on will cause deadlock.
public extension Completing {
  private func wait(waitingBlock: (DispatchSemaphore) -> DispatchTimeoutResult) -> Fallible<Success>? {
    if let completion = self.completion {
      return completion
    }
    let sema = DispatchSemaphore(value: 0)
    var result: Fallible<Success>? = nil

    var handler = self.makeCompletionHandler(executor: .immediate) {
      (completion, originalExecutor) in
      result = completion
      sema.signal()
    }
    defer { handler = nil }

    switch waitingBlock(sema) {
    case .success: return result
    case .timedOut: return nil
    }
  }

  /// Waits for future to complete and returns completion value. Waits forever
  func wait() -> Fallible<Success> {
    return self.wait(waitingBlock: { $0.wait(); return .success })!
  }

  /// Waits for future to complete and returns completion value
  ///
  /// - Parameter timeout: `DispatchTime` to wait completion for
  /// - Returns: completion value or nil if `Future` did not complete in specified timeout
  func wait(timeout: DispatchTime) -> Fallible<Success>? {
    return self.wait(waitingBlock: { $0.wait(timeout: timeout) })
  }

  /// Waits for future to complete and returns completion value
  ///
  /// - Parameter wallTimeout: `DispatchWallTime` to wait completion for
  /// - Returns: completion value or nil if `Future` did not complete in specified timeout
  func wait(wallTimeout: DispatchWallTime) -> Fallible<Success>? {
    return self.wait(waitingBlock: { $0.wait(wallTimeout: wallTimeout) })
  }

  /// Waits for future to complete and returns completion value
  ///
  /// - Parameter nanoseconds: to wait completion for
  /// - Returns: completion value or nil if `Future` did not complete in specified timeout
  func wait(nanoseconds: Int) -> Fallible<Success>? {
    return self.wait(timeout: DispatchTime.now() + .nanoseconds(nanoseconds))
  }

  /// Waits for future to complete and returns completion value
  ///
  /// - Parameter milliseconds: to wait completion for
  /// - Returns: completion value or nil if `Future` did not complete in specified timeout
  func wait(milliseconds: Int) -> Fallible<Success>? {
    return self.wait(timeout: DispatchTime.now() + .milliseconds(milliseconds))
  }

  /// Waits for future to complete and returns completion value
  ///
  /// - Parameter microseconds: to wait completion for
  /// - Returns: completion value or nil if `Future` did not complete in specified timeout
  func wait(microseconds: Int) -> Fallible<Success>? {
    return self.wait(timeout: DispatchTime.now() + .microseconds(microseconds))
  }

  /// Waits for future to complete and returns completion value
  ///
  /// - Parameter seconds: to wait completion for
  /// - Returns: completion value or nil if `Future` did not complete in specified timeout
  func wait(seconds: Double) -> Fallible<Success>? {
    return self.wait(wallTimeout: DispatchWallTime.now().adding(seconds: seconds))
  }
}

public extension Completing {

  /// Returns future that completes after a timeout after completion of self
  func delayedCompletion(timeout: Double, on executor: Executor = .primary) -> Future<Success> {
    let promise = Promise<Success>()
    let handler = self.makeCompletionHandler(executor: .immediate) {
      [weak promise] (completion, _) in
      executor.execute(after: timeout) { [weak promise] executor in
        guard let promise = promise else { return }
        promise.complete(completion, from: executor)
      }
    }
    self._asyncNinja_insertHandlerToReleasePool(handler)

    return promise
  }
}
