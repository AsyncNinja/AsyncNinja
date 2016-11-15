//
//  Copyright (c) 2016 Anton Mironov
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

public protocol Finite : class {
  associatedtype Value
  associatedtype FinalValue
  associatedtype FinalHandler : AnyObject

  var finalValue: Fallible<FinalValue>? { get }

  /// **internal use only**
  func makeFinalHandler(executor: Executor,
                        block: @escaping (Fallible<FinalValue>) -> Void) -> FinalHandler?
}

public extension Finite {
  var isComplete: Bool { return nil != self.finalValue }
  var success: FinalValue? { return self.finalValue?.success }
  var failure: Swift.Error? { return self.finalValue?.failure }
}

public extension Finite {
  /// Transforms Finite<TypeA> => Future<TypeB>
  ///
  /// This method is suitable for **pure**ish transformations (not changing shared state).
  /// Use method mapCompletion(context:executor:transform:) for state changing transformations.
  func mapCompletion<TransformedValue>(
    executor: Executor = .primary,
    transform: @escaping (Fallible<FinalValue>) throws -> TransformedValue
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

  func flatMapCompletion<TransformedValue>(
    executor: Executor = .primary,
    transform: @escaping (Fallible<FinalValue>) throws -> Future<TransformedValue>
    ) -> Future<TransformedValue> {
    return self.mapCompletion(executor: executor, transform: transform).flatten()
  }

  /// Transforms Finite<TypeA> => Future<TypeB>
  ///
  /// This is the same as mapCompletion(executor:transform:) but does not perform transformation if this future fails.
  func mapSuccess<TransformedValue>(
    executor: Executor = .primary,
    transform: @escaping (FinalValue) throws -> TransformedValue
    ) -> Future<TransformedValue> {
    return self.mapCompletion(executor: executor) {
      (value) -> TransformedValue in
      let transformedValue = try value.liftSuccess()
      return try transform(transformedValue)
    }
  }

  func flatMapSuccess<TransformedValue>(
    executor: Executor = .primary,
    transform: @escaping (FinalValue) throws -> Future<TransformedValue>
    ) -> Future<TransformedValue> {
    return self.mapSuccess(executor: executor, transform: transform).flatten()
  }

  /// Recovers failure of this future if there is one.
  func recover(
    executor: Executor = .primary,
    transform: @escaping (Swift.Error) throws -> FinalValue
    ) -> Future<FinalValue> {
    return self.mapCompletion(executor: executor) {
      (value) -> FinalValue in
      if let failure = value.failure { return try transform(failure) }
      if let success = value.success { return success }
      fatalError()
    }
  }

  func flatRecover(
    executor: Executor = .primary,
    transform: @escaping (Swift.Error) throws -> Future<FinalValue>
    ) -> Future<FinalValue> {
    let promise = Promise<FinalValue>()
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
  func mapCompletion<TransformedValue, U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
                     transform: @escaping (U, Fallible<FinalValue>) throws -> TransformedValue
    ) -> Future<TransformedValue> {
    return self.mapCompletion(executor: executor ?? context.executor) {
      [weak context] (value) -> TransformedValue in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, value)
    }
  }

  func flatMapCompletion<TransformedValue, U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    transform: @escaping (U, Fallible<FinalValue>) throws -> Future<TransformedValue>
    ) -> Future<TransformedValue> {
    return self.mapCompletion(context: context, executor: executor, transform: transform).flatten()
  }

  /// Transforms Finite<TypeA> => Future<TypeB>
  ///
  /// This is the same as mapCompletion(context:executor:transform:) but does not perform transformation if this future fails.
  func mapSuccess<TransformedValue, U: ExecutionContext>(context: U, executor: Executor? = nil,
                  transform: @escaping (U, FinalValue) throws -> TransformedValue) -> Future<TransformedValue> {
    return self.mapCompletion(context: context, executor: executor) {
      (context, value) -> TransformedValue in
      let success = try value.liftSuccess()
      return try transform(context, success)
    }
  }

  func flatMapSuccess<TransformedValue, U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    transform: @escaping (U, FinalValue) throws -> Future<TransformedValue>
    ) -> Future<TransformedValue> {
    return self.mapSuccess(context: context, executor: executor, transform: transform).flatten()
  }

  /// Recovers failure of this future if there is one with contextual transformer.
  func recover<U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    transform: @escaping (U, Swift.Error) throws -> FinalValue
    ) -> Future<FinalValue> {
    return self.mapCompletion(context: context, executor: executor) {
      (context, value) -> FinalValue in
      if let failure = value.failure { return try transform(context, failure) }
      if let success = value.success { return success }
      fatalError()
    }
  }

  func flatRecover<U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    transform: @escaping (U, Swift.Error) throws -> Future<FinalValue>
    ) -> Future<FinalValue> {
    return self.flatRecover(executor: executor ?? context.executor) {
      [weak context] (failure) -> Future<FinalValue> in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, failure)
    }
  }
}

public extension Finite {
  /// Performs block when final value or failure becomes available.
  ///
  /// This method is suitable for applying final value of future to context.
  func onComplete<U: ExecutionContext>(context: U, executor: Executor? = nil,
               block: @escaping (U, Fallible<FinalValue>) -> Void) {
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
                 block: @escaping (U, FinalValue) -> Void) {
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
  func wait(waitingBlock: (DispatchSemaphore) -> DispatchTimeoutResult) -> Fallible<FinalValue>? {
    if let finalValue = self.finalValue {
      return finalValue
    }
    let sema = DispatchSemaphore(value: 0)
    var result: Fallible<FinalValue>? = nil

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

  func wait() -> Fallible<FinalValue> {
    return self.wait(waitingBlock: { $0.wait(); return .success })!
  }

  func wait(timeout: DispatchTime) -> Fallible<FinalValue>? {
    return self.wait(waitingBlock: { $0.wait(timeout: timeout) })
  }

  func wait(wallTimeout: DispatchWallTime) -> Fallible<FinalValue>? {
    return self.wait(waitingBlock: { $0.wait(wallTimeout: wallTimeout) })
  }
}

public extension Finite {
  func delayedFinal(timeout: Double) -> Future<FinalValue> {
    let promise = Promise<FinalValue>()
    let handler = self.makeFinalHandler(executor: .immediate) {
      [weak promise] (value) in
      guard let promise = promise else { return }
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
