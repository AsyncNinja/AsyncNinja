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
    promise._asyncNinja_retainHandlerUntilFinalization(handler)
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
    promise._asyncNinja_retainHandlerUntilFinalization(handler)
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
    promise._asyncNinja_retainHandlerUntilFinalization(handler)

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
    let handler = self.makeCompletionHandler(executor: .immediate) {
      [weak promise] (failure, originalExecutor) in
      guard let promise = promise else { return }
      switch failure {
      case .success(let future):
        let handler = future.makeCompletionHandler(executor: .immediate) {
          [weak promise] (completion, originalExecutor) -> Void in
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

    let handler = self.makeCompletionHandler(executor: .immediate) {
      [weak producer] (failure, originalExecutor) in
      guard let producer = producer else { return }
      switch failure {
      case .success(let channel):
        let completionHandler = channel.makeCompletionHandler(executor: .immediate) {
          [weak producer] (completion, originalExecutor) -> Void in
          producer?.complete(completion, from: originalExecutor)
        }
        producer._asyncNinja_retainHandlerUntilFinalization(completionHandler)

        let updateHandler = channel.makeUpdateHandler(executor: .immediate) {
          [weak producer] (update, originalExecutor) -> Void in
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
