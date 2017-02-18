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

/// A protocol for objects that can eventually complete with value
public protocol Completable: class {
  associatedtype Success
  associatedtype CompletionHandler: AnyObject
  
  /// Returns either completion value for complete `Completable` or nil otherwise
  var completion: Fallible<Success>? { get }

  /// **internal use only**
  func makeCompletionHandler(executor: Executor,
                             _ block: @escaping (Fallible<Success>) -> Void) -> CompletionHandler?

  /// **internal use only**
  func insertToReleasePool(_ releasable: Releasable)
}

public extension Completable {

  /// Shorthand property that returns true if `Completion` is complete
  var isComplete: Bool {
    switch self.completion {
    case .some: return true
    case .none: return false
    }
  }

  /// Shorthand property that returns success
  /// if `Completable` is completed with success or nil otherwise
  var success: Success? { return self.completion?.success }

  /// Shorthand property that returns failure value
  /// if `Completable` is completed with failure or nil otherwise
  var failure: Swift.Error? { return self.completion?.failure }
}

public extension Completable {
  /// Transforms Completable<SuccessA> => Completable<SuccessB>
  ///
  /// This method is suitable for **pure**ish transformations (not changing shared state).
  /// Use method mapCompletion(context:executor:transform:) for state changing transformations.
  func mapCompletion<Transformed>(
    executor: Executor = .primary,
    _ transform: @escaping (Fallible<Success>) throws -> Transformed
    ) -> Future<Transformed> {
    let promise = Promise<Transformed>()
    let handler = self.makeCompletionHandler(executor: executor) { [weak promise] (completion) -> Void in
      guard case .some = promise else { return }
      let transformedValue = fallible { try transform(completion) }
      promise?.complete(with: transformedValue )
    }
    promise.insertHandlerToReleasePool(handler)
    return promise
  }

  /// Transforms Completable<SuccessA> => Future<SuccessB>. Flattens future returned by the transform
  ///
  /// This method is suitable for **pure**ish transformations (not changing shared state).
  /// Use method flatMapCompletion(context:executor:transform:) for state changing transformations.
  func flatMapCompletion<Transformed>(
    executor: Executor = .primary,
    _ transform: @escaping (Fallible<Success>) throws -> Future<Transformed>
    ) -> Future<Transformed> {
    return self.mapCompletion(executor: executor, transform).flatten()
  }

  /// Transforms Completable<SuccessA> => Future<SuccessB>
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

  /// Transforms Completable<SuccessA> => Future<SuccessB>. Flattens future returned by the transform
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
    return self.mapCompletion(executor: .immediate) {
      (value) -> Success in
      switch value {
      case .success(let success): return success
      case .failure: return success
      }
    }
  }

  /// Recovers failure of this future if there is one
  func recover(
    executor: Executor = .primary,
    _ transform: @escaping (Swift.Error) throws -> Success
    ) -> Future<Success> {
    return self.mapCompletion(executor: executor) {
      (value) -> Success in
      switch value {
      case .success(let success): return success
      case .failure(let failure): return try transform(failure)
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
      [weak promise] (value) -> Void in
      guard case .some = promise else { return }

      switch value {
      case let .success(success):
        promise?.succeed(with: success)
      case let .failure(failure):
        do {
          let future = try transform(failure)
          promise?.complete(with: future)
        }
        catch {
          promise?.fail(with: error)
        }
      }
    }
    promise.insertHandlerToReleasePool(handler)
    return promise
  }
}

public extension Completable {
  /// Transforms Completable<SuccessA> => Completable<SuccessB>
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

  /// Transforms Completable<SuccessA> => Future<SuccessB>
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

  /// Transforms Completable<SuccessA> => Future<SuccessB>. Flattens future returned by the transform
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
  /// Flattens future returned by the transform
  func flatRecover<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (C, Swift.Error) throws -> Future<Success>
    ) -> Future<Success> {
    return self.flatRecover(executor: executor ?? context.executor) {
      [weak context] (failure) -> Future<Success> in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, failure)
    }
  }
}

public extension Completable {
  /// Performs block when completion value.
  ///
  /// This method is method is less preferable then onComplete(context: ...).
  func onComplete(
    executor: Executor = .primary,
    _ block: @escaping (Fallible<Success>) -> Void) {
    let handler = self.makeCompletionHandler(executor: executor) {
      block($0)
    }
    self.insertHandlerToReleasePool(handler)
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

public extension Completable {
  /// Performs block when completion value.
  ///
  /// This method is suitable for applying completion of future to context.
  func onComplete<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ block: @escaping (C, Fallible<Success>) -> Void) {
    // Test: FutureTests.testOnCompleteContextual_ContextAlive
    // Test: FutureTests.testOnCompleteContextual_ContextDead
    let handler = self.makeCompletionHandler(executor: executor ?? context.executor) {
      [weak context] in
      guard let context = context else { return }
      block(context, $0)
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
      (context, value) in
      if let success = value.success {
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
      (context, value) in
      if let failure = value.failure {
        block(context, failure)
      }
    }
  }
}

/// Each of these methods synchronously awaits for future to complete.
/// Using this method is **strongly** discouraged. Calling it on the same serial queue
/// as any code performed on the same queue this future depends on will cause deadlock.
public extension Completable {
  private func wait(waitingBlock: (DispatchSemaphore) -> DispatchTimeoutResult) -> Fallible<Success>? {
    if let completion = self.completion {
      return completion
    }
    let sema = DispatchSemaphore(value: 0)
    var result: Fallible<Success>? = nil

    var handler = self.makeCompletionHandler(executor: .immediate) {
      result = $0
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
  /// - Parameter seconds: to wait completion for
  /// - Returns: completion value or nil if `Future` did not complete in specified timeout
  func wait(seconds: Double) -> Fallible<Success>? {
    return self.wait(nanoseconds: Int(seconds * 1_000_000_000))
  }
}

public extension Completable {

  /// Returns future that completes after a timeout after completion of self
  func delayedCompletion(timeout: Double) -> Future<Success> {
    let promise = Promise<Success>()
    let handler = self.makeCompletionHandler(executor: .immediate) {
      [weak promise] (value) in
      Executor.primary.execute(after: timeout) { [weak promise] in
        guard let promise = promise else { return }
        promise.complete(with: value)
      }
    }
    self.insertHandlerToReleasePool(handler)

    return promise
  }
}

extension Completable {
  
  /// **internal use only**
  func insertHandlerToReleasePool(_ handler: AnyObject?) {
    if let handler = handler {
      self.insertToReleasePool(handler)
    }
  }
  
}
