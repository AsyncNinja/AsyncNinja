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

/// Future is a proxy of value that will be available at some point in the future.
public class Future<FinalValue> : Finite {
  public typealias Value = Fallible<FinalValue>
  public typealias Handler = FutureHandler<FinalValue>
  public typealias FinalHandler = Handler

  /// Returns either final value for complete `Future` or nil otherwise
  public var finalValue: Fallible<FinalValue>? { assertAbstract() }

  /// Returns either final value if future is complete or nil
  public var value: Value? { return self.finalValue }

  /// Base future is **abstract**.
  ///
  /// Use `Promise` or `future(executor:block)` or `future(context:executor:block)` to make future.
  init() { }

  /// **Internal use only**.
  public func makeFinalHandler(executor: Executor,
                               block: @escaping (Fallible<FinalValue>) -> Void) -> FinalHandler? {
    assertAbstract()
  }

  /// **Internal use only**.
  public func insertToReleasePool(_ releasable: Releasable) {
    assertAbstract()
  }
}

public extension Future {
  /// Applies the transformation to the future
  ///
  /// - Parameters:
  ///   - executor: is `Executor` to execute transform on
  ///   - transform: is block to execute on successful completion of original future. Return from transformation block will cause returned future to complete successfuly. Throw from transformation block will returned future to complete with failure
  ///   - finalValue: is a success value of original future
  ///
  /// - Returns: transformed future
  func map<T>(executor: Executor = .primary,
           transform: @escaping (_ finalValue: FinalValue) throws -> T) -> Future<T> {
    // Test: FutureTests.testMap_Success
    // Test: FutureTests.testMap_Failure
    return self.mapSuccess(executor: executor, transform: transform)
  }

  /// Applies the transformation to the future and flattens future returned by transformation
  ///
  /// - Parameters:
  ///   - executor: is `Executor` to execute transform on
  ///   - transform: is block to execute on successful completion of original future. Return from transformation block will cause returned future to complete with future. Throw from transformation block will returned future to complete with failure
  ///   - finalValue: is a success value of original future
  ///
  /// - Returns: transformed future
  func flatMap<T>(executor: Executor = .primary,
               transform: @escaping (_ finalValue: FinalValue) throws -> Future<T>) -> Future<T> {
    return self.flatMapSuccess(executor: executor, transform: transform)
  }

  /// Applies the transformation to the future
  ///
  /// - Parameters:
  ///   - context: is `ExecutionContext` to perform transform on. Instance of context will be passed as the first argument to the transformation. Transformation will not be executed if executor was deallocated before execution, returned future will fail with `AsyncNinjaError.contextDeallocated` error
  ///   - executor: is `Executor` to override executor provided by context
  ///   - transform: is block to execute on successful completion of original future. Return from transformation block will cause returned future to complete successfuly. Throw from transformation block will returned future to complete with failure
  ///   - strongContext: is `ExecutionContext` restored from weak reference of context passed to method
  ///   - finalValue: is a success value of original future
  /// - Returns: transformed future
  func map<T, U: ExecutionContext>(context: U, executor: Executor? = nil,
           transform: @escaping (_ strongContext: U, _ finalValue: FinalValue) throws -> T) -> Future<T> {
    // Test: FutureTests.testMapContextual_Success_ContextAlive
    // Test: FutureTests.testMapContextual_Success_ContextDead
    // Test: FutureTests.testMapContextual_Failure_ContextAlive
    // Test: FutureTests.testMapContextual_Failure_ContextDead
    return self.mapSuccess(context: context, executor: executor, transform: transform)
  }

  /// Applies the transformation to the future and flattens future returned by transformation
  ///
  /// - Parameters:
  ///   - context: is `ExecutionContext` to perform transform on. Instance of context will be passed as the first argument to the transformation. Transformation will not be executed if executor was deallocated before execution, returned future will fail with `AsyncNinjaError.contextDeallocated` error
  ///   - executor: is `Executor` to override executor provided by context
  ///   - transform: is block to execute on successful completion of original future. Return from transformation block will cause returned future to complete with future. Throw from transformation block will returned future to complete with failure
  ///   - strongContext: is `ExecutionContext` restored from weak reference of context passed to method
  ///   - finalValue: is a success value of original future
  /// - Returns: transformed future
  func flatMap<T, U: ExecutionContext>(context: U, executor: Executor? = nil,
               transform: @escaping (_ strongContext: U, _ finalValue: FinalValue) throws -> Future<T>) -> Future<T> {
    return self.flatMapSuccess(context: context, executor: executor, transform: transform)
  }

  /// Makes future with delayed completion
  ///
  /// - Parameter timeout: is `Double` (seconds) to delay competion of original future with.
  /// - Returns: delayed future
  func delayed(timeout: Double) -> Future<FinalValue> {
    return self.delayedFinal(timeout: timeout)
  }
}

public extension Future where FinalValue : Finite {
  /// Flattens two nested futures
  ///
  /// - Returns: flattened future
  func flatten() -> Future<FinalValue.FinalValue> {
    // Test: FutureTests.testFlatten
    // Test: FutureTests.testFlatten_OuterFailure
    // Test: FutureTests.testFlatten_InnerFailure
    let promise = Promise<FinalValue.FinalValue>()
    let handler = self.makeFinalHandler(executor: .immediate) { [weak promise] (failure) in
      guard let promise = promise else { return }
      switch failure {
      case .success(let future):
        let handler = future.makeFinalHandler(executor: .immediate) {
          [weak promise] (final) -> Void in
          promise?.complete(with: final)
        }
        if let handler = handler {
          promise.insertToReleasePool(handler)
        }
      case .failure(let error):
        promise.fail(with: error)
      }
    }

    if let handler = handler {
      promise.insertToReleasePool(handler)
    }

    return promise
  }
}

public extension DispatchGroup {
  /// Makes future from of `DispatchGroups`'s notify after balancing all enters and leaves
  var completionFuture: Future<Void> {
    // Test: FutureTests.testGroupCompletionFuture
    let promise = Promise<Void>()
    self.notify(queue: DispatchQueue.global()) { [weak promise] in
      promise?.succeed(with: Void())
    }
    return promise
  }
}

/// **Internal use only**
///
/// Each subscription to a future value will be expressed in such handler.
/// Future will accumulate handlers until completion or deallocacion.
public class FutureHandler<T> {
  let executor: Executor
  let block: (Fallible<T>) -> Void
  let owner: Future<T>

  init(executor: Executor, block: @escaping (Fallible<T>) -> Void, owner: Future<T>) {
    self.executor = executor
    self.block = block
    self.owner = owner
  }

  func handle(_ value: Fallible<T>) {
    self.executor.execute { self.block(value) }
  }
}
