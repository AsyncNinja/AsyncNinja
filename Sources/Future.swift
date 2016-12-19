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

  public var finalValue: Fallible<FinalValue>? {
    /* abstract */
    fatalError()
  }
  public var value: Value? { return self.finalValue }

  /// Base future is **abstract**.
  ///
  /// Use `Promise` or `future(executor:block)` or `future(context:executor:block)` to make future.
  init() { }

  /// **Internal use only**.
  public func makeFinalHandler(executor: Executor,
                               block: @escaping (Fallible<FinalValue>) -> Void) -> FinalHandler? {
    /* abstract */
    fatalError()
  }
  
  /// **Internal use only**.
  public func insertToReleasePool(_ releasable: Releasable) {
    /* abstract */
    fatalError()
  }
}

public extension Future {
  final func map<T>(executor: Executor = .primary,
                 transform: @escaping (FinalValue) throws -> T) -> Future<T> {
    // Test: FutureTests.testMap_Success
    // Test: FutureTests.testMap_Failure
    return self.mapSuccess(executor: executor, transform: transform)
  }

  final func flatMap<T>(executor: Executor = .primary,
                 transform: @escaping (FinalValue) throws -> Future<T>) -> Future<T> {
    return self.flatMapSuccess(executor: executor, transform: transform)
  }

  final func map<T, U: ExecutionContext>(context: U, executor: Executor? = nil,
                 transform: @escaping (U, FinalValue) throws -> T) -> Future<T> {
    // Test: FutureTests.testMapContextual_Success_ContextAlive
    // Test: FutureTests.testMapContextual_Success_ContextDead
    // Test: FutureTests.testMapContextual_Failure_ContextAlive
    // Test: FutureTests.testMapContextual_Failure_ContextDead
    return self.mapSuccess(context: context, executor: executor, transform: transform)
  }

  final func flatMap<T, U: ExecutionContext>(context: U, executor: Executor? = nil,
                 transform: @escaping (U, FinalValue) throws -> Future<T>) -> Future<T> {
    return self.flatMapSuccess(context: context, executor: executor, transform: transform)
  }

  func delayed(timeout: Double) -> Future<FinalValue> {
    return self.delayedFinal(timeout: timeout)
  }
}

public extension Future where FinalValue : Finite {
  /// flattens combination of two nested unfaillable futures to a signle unfallible one
  final func flatten() -> Future<FinalValue.FinalValue> {
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

/// Asynchrounously executes block on executor and wraps returned value into future
public func future<T>(executor: Executor = .primary, block: @escaping () throws -> T) -> Future<T> {
  // Test: FutureTests.testMakeFutureOfBlock_Success
  // Test: FutureTests.testMakeFutureOfBlock_Failure
  let promise = Promise<T>()
  executor.execute { [weak promise] in
    guard let promise = promise else { return }
    promise.complete(with: fallible(block: block))
  }
  return promise
}

private func promise<T>(executor: Executor, after timeout: Double, cancellationToken: CancellationToken?,
                     block: @escaping () throws -> T) -> Promise<T> {
  let promise = Promise<T>()
  
  cancellationToken?.notifyCancellation { [weak promise] in
    promise?.cancel()
  }
  
  executor.execute(after: timeout) { [weak promise] in
    guard let promise = promise else { return }
    
    if cancellationToken?.isCancelled ?? false {
      promise.cancel()
    } else {
      let completion = fallible(block: block)
      promise.complete(with: completion)
    }
  }
  return promise
}

/// Asynchrounously executes block after timeout on executor and wraps returned value into future
public func future<T>(executor: Executor = .primary, after timeout: Double, cancellationToken: CancellationToken? = nil,
                   block: @escaping () throws -> T) -> Future<T> {
  // Test: FutureTests.testMakeFutureOfDelayedFallibleBlock_Success
  // Test: FutureTests.testMakeFutureOfDelayedFallibleBlock_Failure
  return promise(executor: executor, after: timeout, cancellationToken: cancellationToken, block: block)
}

public func future<T, U : ExecutionContext>(context: U, executor: Executor? = nil,
                   block: @escaping (U) throws -> T) -> Future<T> {
  // Test: FutureTests.testMakeFutureOfContextualFallibleBlock_Success_ContextAlive
  // Test: FutureTests.testMakeFutureOfContextualFallibleBlock_Success_ContextDead
  // Test: FutureTests.testMakeFutureOfContextualFallibleBlock_Failure_ContextAlive
  // Test: FutureTests.testMakeFutureOfContextualFallibleBlock_Failure_ContextDead
  return future(executor: executor ?? context.executor) { [weak context] () -> T in
    guard let context = context
      else { throw AsyncNinjaError.contextDeallocated }

    return try block(context)
  }
}

public func future<T, U : ExecutionContext>(context: U, executor: Executor? = nil,
                   after timeout: Double, cancellationToken: CancellationToken? = nil,
                   block: @escaping (U) throws -> T) -> Future<T> {
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextAlive
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Success_ContextDead
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Success_EarlyContextDead
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextAlive
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Failure_ContextDead
  // Test: FutureTests.testMakeFutureOfDelayedContextualFallibleBlock_Failure_EarlyContextDead
  let promiseValue = promise(executor: executor ?? context.executor, after: timeout, cancellationToken: cancellationToken) { [weak context] () -> T in
    guard let context = context
      else { throw AsyncNinjaError.contextDeallocated }

    return try block(context)
  }

  context.notifyDeinit { [weak promiseValue] in promiseValue?.cancelBecauseOfDeallicatedContext() }

  return promiseValue
}

public extension DispatchGroup {
  // Test: FutureTests.testGroupCompletionFuture
  var completionFuture: Future<Void> {
    let promise = Promise<Void>()
    self.notify(queue: DispatchQueue.global(qos: .default)) { [weak promise] in
      promise?.succeed(with: Void())
    }
    return promise
  }
}

/// **Internal use only**
///
/// Each subscription to a future value will be expressed in such handler.
/// Future will accumulate handlers until completion or deallocacion.
final public class FutureHandler<T> {
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
