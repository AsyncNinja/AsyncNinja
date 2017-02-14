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

/// A protocol for objects that can eventually finish with value
public protocol Finite: class {
  associatedtype SuccessValue
  associatedtype FinalHandler: AnyObject

  /// Returns either final value for complete `Finite` or nil otherwise
  var finalValue: Fallible<SuccessValue>? { get }

  /// **internal use only**
  func makeFinalHandler(executor: Executor,
                        block: @escaping (Fallible<SuccessValue>) -> Void) -> FinalHandler?

  /// **internal use only**
  func insertToReleasePool(_ releasable: Releasable)
}

public extension Finite {

  /// Shorthand property that returns true if `Finite` is complete
  var isComplete: Bool {
    switch self.finalValue {
    case .some: return true
    case .none: return false
    }
  }

  /// Shorthand property that returns success value
  /// if `Finite` completed with success or nil otherwise
  var success: SuccessValue? { return self.finalValue?.success }

  /// Shorthand property that returns failure value
  /// if `Finite` completed with failure or nil otherwise
  var failure: Swift.Error? { return self.finalValue?.failure }
}

public extension Finite {
  /// Transforms Finite<TypeA> => Future<TypeB>
  ///
  /// This method is suitable for **pure**ish transformations (not changing shared state).
  /// Use method mapCompletion(context:executor:transform:) for state changing transformations.
  func mapCompletion<TransformedValue>(
    executor: Executor = .primary,
    transform: @escaping (Fallible<SuccessValue>) throws -> TransformedValue
    ) -> Future<TransformedValue> {
    let promise = Promise<TransformedValue>()
    let handler = self.makeFinalHandler(executor: executor) {
      [weak promise] (value) -> Void in
      guard nil != promise else { return }
      let transformedValue = fallible { try transform(value) }
      promise?.complete(with: transformedValue )
    }
    if let handler = handler {
      promise.insertToReleasePool(handler)
    }
    return promise
  }

  /// Transforms Finite<TypeA> => Future<TypeB>. Flattens future returned by the transform
  ///
  /// This method is suitable for **pure**ish transformations (not changing shared state).
  /// Use method flatMapCompletion(context:executor:transform:) for state changing transformations.
  func flatMapCompletion<TransformedValue>(
    executor: Executor = .primary,
    transform: @escaping (Fallible<SuccessValue>) throws -> Future<TransformedValue>
    ) -> Future<TransformedValue> {
    return self.mapCompletion(executor: executor, transform: transform).flatten()
  }

  /// Transforms Finite<TypeA> => Future<TypeB>
  ///
  /// This is the same as mapCompletion(executor:transform:)
  /// but does not perform transformation if this future fails.
  func mapSuccess<TransformedValue>(
    executor: Executor = .primary,
    transform: @escaping (SuccessValue) throws -> TransformedValue
    ) -> Future<TransformedValue> {
    return self.mapCompletion(executor: executor) {
      (value) -> TransformedValue in
      let transformedValue = try value.liftSuccess()
      return try transform(transformedValue)
    }
  }

  /// Transforms Finite<TypeA> => Future<TypeB>. Flattens future returned by the transform
  ///
  /// This is the same as flatMapCompletion(executor:transform:)
  /// but does not perform transformation if this future fails.
  func flatMapSuccess<TransformedValue>(
    executor: Executor = .primary,
    transform: @escaping (SuccessValue) throws -> Future<TransformedValue>
    ) -> Future<TransformedValue> {
    return self.mapSuccess(executor: executor, transform: transform).flatten()
  }

  /// Recovers failure of this future if there is one.
  func recover(
    executor: Executor = .primary,
    transform: @escaping (Swift.Error) throws -> SuccessValue
    ) -> Future<SuccessValue> {
    return self.mapCompletion(executor: executor) {
      (value) -> SuccessValue in
      if let failure = value.failure { return try transform(failure) }
      if let success = value.success { return success }
      fatalError()
    }
  }

  /// Recovers failure of this future if there is one. Flattens future returned by the transform
  func flatRecover(
    executor: Executor = .primary,
    transform: @escaping (Swift.Error) throws -> Future<SuccessValue>
    ) -> Future<SuccessValue> {
    let promise = Promise<SuccessValue>()
    let handler = self.makeFinalHandler(executor: executor) {
      [weak promise] (value) -> Void in
      guard nil != promise else { return }

      switch value {
      case let .success(success):
        promise?.succeed(with: success)
      case let .failure(failure):
        do { promise?.complete(with: try transform(failure)) }
        catch { promise?.fail(with: error) }
      }
    }
    if let handler = handler {
      promise.insertToReleasePool(handler)
    }
    return promise
  }
}

public extension Finite {
  /// Transforms Finite<TypeA> => Future<TypeB>
  ///
  /// This method is suitable for impure transformations (changing state of context).
  /// Use method mapCompletion(context:transform:) for pure -ish transformations.
  func mapCompletion<T, C: ExecutionContext>(context: C,
                     executor: Executor? = nil,
                     transform: @escaping (C, Fallible<SuccessValue>) throws -> T
    ) -> Future<T> {
    return self.mapCompletion(executor: executor ?? context.executor) {
      [weak context] (value) -> T in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, value)
    }
  }

  /// Transforms Finite<TypeA> => Future<TypeB>. Flattens future returned by the transform
  ///
  /// This method is suitable for impure transformations (changing state of context).
  /// Use method flatMapCompletion(context:transform:) for pure -ish transformations.
  func flatMapCompletion<T, C: ExecutionContext>(context: C,
                         executor: Executor? = nil,
                         transform: @escaping (C, Fallible<SuccessValue>) throws -> Future<T>
    ) -> Future<T> {
    return self.mapCompletion(context: context, executor: executor, transform: transform).flatten()
  }

  /// Transforms Finite<TypeA> => Future<TypeB>
  ///
  /// This is the same as mapCompletion(context:executor:transform:)
  /// but does not perform transformation if this future fails.
  func mapSuccess<T, C: ExecutionContext>(context: C,
                  executor: Executor? = nil,
                  transform: @escaping (C, SuccessValue) throws -> T
    ) -> Future<T> {
    return self.mapCompletion(context: context, executor: executor) {
      (context, value) -> T in
      let success = try value.liftSuccess()
      return try transform(context, success)
    }
  }

  /// Transforms Finite<TypeA> => Future<TypeB>. Flattens future returned by the transform
  ///
  /// This is the same as flatMapCompletion(context:executor:transform:)
  /// but does not perform transformation if this future fails.
  func flatMapSuccess<T, C: ExecutionContext>(context: C,
                      executor: Executor? = nil,
                      transform: @escaping (C, SuccessValue) throws -> Future<T>
    ) -> Future<T> {
    return self.mapSuccess(context: context, executor: executor, transform: transform).flatten()
  }

  /// Recovers failure of this future if there is one with contextual transformer.
  func recover<C: ExecutionContext>(context: C,
               executor: Executor? = nil,
               transform: @escaping (C, Swift.Error) throws -> SuccessValue
    ) -> Future<SuccessValue> {
    return self.mapCompletion(context: context, executor: executor) {
      (context, value) -> SuccessValue in
      if let failure = value.failure { return try transform(context, failure) }
      if let success = value.success { return success }
      fatalError()
    }
  }

  /// Recovers failure of this future if there is one with contextual transformer.
  /// Flattens future returned by the transform
  func flatRecover<C: ExecutionContext>(context: C,
                   executor: Executor? = nil,
                   transform: @escaping (C, Swift.Error) throws -> Future<SuccessValue>
    ) -> Future<SuccessValue> {
    return self.flatRecover(executor: executor ?? context.executor) {
      [weak context] (failure) -> Future<SuccessValue> in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, failure)
    }
  }
}

public extension Finite {
  /// Performs block when final value or failure becomes available.
  ///
  /// This method is method is less preferable then onComplete(context: ...).
  func onComplete(executor: Executor = .primary,
                  block: @escaping (Fallible<SuccessValue>) -> Void) {
    let handler = self.makeFinalHandler(executor: executor) {
      block($0)
    }
    if let handler = handler {
      self.insertToReleasePool(handler)
    }
  }

  /// Performs block when final value becomes available.
  func onSuccess(executor: Executor = .primary,
                 block: @escaping (SuccessValue) -> Void) {
    self.onComplete(executor: executor) { $0.onSuccess(block) }
  }
  
  /// Performs block when failure becomes available.
  func onFailure(executor: Executor = .primary,
                 block: @escaping (Swift.Error) -> Void) {
    self.onComplete(executor: executor) { $0.onFailure(block) }
  }
}

public extension Finite {
  /// Performs block when final value or failure becomes available.
  ///
  /// This method is suitable for applying final value of future to context.
  func onComplete<U: ExecutionContext>(context: U, executor: Executor? = nil,
               block: @escaping (U, Fallible<SuccessValue>) -> Void) {
    // Test: FutureTests.testOnCompleteContextual_ContextAlive
    // Test: FutureTests.testOnCompleteContextual_ContextDead
    let handler = self.makeFinalHandler(executor: executor ?? context.executor) {
      [weak context] (final) in
      guard let context = context else { return }
      block(context, final)
    }

    if let handler = handler {
      context.releaseOnDeinit(handler)
    }
  }

  /// Performs block when final value becomes available.
  func onSuccess<U: ExecutionContext>(context: U, executor: Executor? = nil,
                 block: @escaping (U, SuccessValue) -> Void) {
    self.onComplete(context: context, executor: executor) {
      (context, value) in
      guard let success = value.success else { return }
      block(context, success)
    }
  }

  /// Performs block when failure becomes available.
  func onFailure<U: ExecutionContext>(context: U, executor: Executor? = nil,
                 block: @escaping (U, Swift.Error) -> Void) {
    self.onComplete(context: context, executor: executor) {
      (context, value) in
      guard let failure = value.failure else { return }
      block(context, failure)
    }
  }
}

/// Each of these methods synchronously awaits for future to complete.
/// Using this method is **strongly** discouraged. Calling it on the same serial queue
/// as any code performed on the same queue this future depends on will cause deadlock.
public extension Finite {
  private func wait(waitingBlock: (DispatchSemaphore) -> DispatchTimeoutResult) -> Fallible<SuccessValue>? {
    if let finalValue = self.finalValue {
      return finalValue
    }
    let sema = DispatchSemaphore(value: 0)
    var result: Fallible<SuccessValue>? = nil

    var handler = self.makeFinalHandler(executor: .immediate) {
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
  func wait() -> Fallible<SuccessValue> {
    return self.wait(waitingBlock: { $0.wait(); return .success })!
  }

  /// Waits for future to complete and returns completion value
  ///
  /// - Parameter timeout: `DispatchTime` to wait completion for
  /// - Returns: completion value or nil if `Future` did not complete in specified timeout
  func wait(timeout: DispatchTime) -> Fallible<SuccessValue>? {
    return self.wait(waitingBlock: { $0.wait(timeout: timeout) })
  }

  /// Waits for future to complete and returns completion value
  ///
  /// - Parameter wallTimeout: `DispatchWallTime` to wait completion for
  /// - Returns: completion value or nil if `Future` did not complete in specified timeout
  func wait(wallTimeout: DispatchWallTime) -> Fallible<SuccessValue>? {
    return self.wait(waitingBlock: { $0.wait(wallTimeout: wallTimeout) })
  }

  /// Waits for future to complete and returns completion value
  ///
  /// - Parameter nanoseconds: to wait completion for
  /// - Returns: completion value or nil if `Future` did not complete in specified timeout
  func wait(nanoseconds: Int) -> Fallible<SuccessValue>? {
    return self.wait(timeout: DispatchTime.now() + .nanoseconds(nanoseconds))
  }

  /// Waits for future to complete and returns completion value
  ///
  /// - Parameter seconds: to wait completion for
  /// - Returns: completion value or nil if `Future` did not complete in specified timeout
  func wait(seconds: Double) -> Fallible<SuccessValue>? {
    return self.wait(nanoseconds: Int(seconds * 1_000_000_000))
  }
}

public extension Finite {

  /// Returns future that completes after a timeout after completion of self
  func delayedFinal(timeout: Double) -> Future<SuccessValue> {
    let promise = Promise<SuccessValue>()
    let handler = self.makeFinalHandler(executor: .immediate) {
      [weak promise] (value) in
      Executor.primary.execute(after: timeout) { [weak promise] in
        guard let promise = promise else { return }
        promise.complete(with: value)
      }
    }
    if let handler = handler {
      promise.insertToReleasePool(handler)
    }

    return promise
  }
}

extension Finite {
  func insertHandlerToReleasePool(_ handler: AnyObject?) {
    if let handler = handler {
      self.insertToReleasePool(handler)
    }
  }
}
