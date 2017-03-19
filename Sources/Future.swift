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

/// Future is a proxy of value that will be available at some point in the future.
public class Future<S>: Completing {
  public typealias Success = S
  public typealias Handler = FutureHandler<Success>
  public typealias CompletionHandler = Handler

  /// Returns either completion for complete `Future` or nil otherwise
  public var completion: Fallible<Success>? { assertAbstract() }

  /// Returns either completion for complete `Future` or nil otherwise
  public var value: Fallible<Success>? { return self.completion }

  /// Base future is **abstract**.
  ///
  /// Use `Promise` or `future(executor:block)` or `future(context:executor:block)` to make future.
  init() { }

  /// **Internal use only**.
  public func makeCompletionHandler(
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void) -> AnyObject? {
    assertAbstract()
  }

  /// **Internal use only**.
  public func _asyncNinja_retainUntilFinalization(_ releasable: Releasable) {
    assertAbstract()
  }
  
  /// **Internal use only**.
  public func _asyncNinja_notifyFinalization(_ block: @escaping () -> Void) {
    assertAbstract()
  }

  public func staticCast<T>() -> Future<T> {
    return map(executor: .immediate) { $0 as! T }
  }
}

// MARK: - Description
extension Future: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of this instance.
  public var description: String {
    return description(withBody: "Future")
  }

  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    return description(withBody: "Future<\(Success.self)>")
  }

  /// **internal use only**
  private func description(withBody body: String) -> String {
    switch completion {
    case .some(.success(let value)):
      return "Succeded(\(value)) \(body)"
    case .some(.failure(let error)):
      return "Failed(\(error)) \(body)"
    case .none:
      return "Incomplete \(body)"
    }
  }
}

// MARK: - Transformations
public extension Future {
  /// Applies the transformation to the future
  ///
  /// - Parameters:
  ///   - executor: is `Executor` to execute transform on
  ///   - transform: is block to execute on successful completion of original future.
  ///     Return from transformation block will cause returned future to complete successfuly.
  ///     Throw from transformation block will returned future to complete with failure
  ///   - success: is a success value of original future
  ///
  /// - Returns: transformed future
  func map<T>(
    executor: Executor = .primary,
    _ transform: @escaping (_ success: Success) throws -> T
    ) -> Future<T>
  {
    // Test: FutureTests.testMap_Success
    // Test: FutureTests.testMap_Failure
    return mapSuccess(executor: executor, transform)
  }

  /// Applies the transformation to the future and flattens future returned by transformation
  ///
  /// - Parameters:
  ///   - executor: is `Executor` to execute transform on
  ///   - transform: is block to execute on successful completion of original future.
  ///     Return from transformation block will cause returned future to complete with future.
  ///     Throw from transformation block will returned future to complete with failure
  ///   - success: is a success value of original future
  ///
  /// - Returns: transformed future
  func flatMap<T: Completing>(
    executor: Executor = .primary,
    transform: @escaping (_ success: Success) throws -> T
    ) -> Future<T.Success>
  {
    return flatMapSuccess(executor: executor, transform)
  }

  /// Applies the transformation to the future and flattens channel returned by transformation
  ///
  /// - Parameters:
  ///   - executor: is `Executor` to execute transform on
  ///   - transform: is block to execute on successful completion of original future.
  ///     Return from transformation block will cause returned channel to complete with future.
  ///     Throw from transformation block will returned future to complete with failure
  ///   - success: is a success value of original future
  ///
  /// - Returns: transformed future
  func flatMap<T: Completing&Updating>(
    executor: Executor = .primary,
    transform: @escaping (_ success: Success) throws -> T
    ) -> Channel<T.Update, T.Success>
  {
    return flatMapSuccess(executor: executor, transform)
  }

  /// Applies the transformation to the future
  ///
  /// - Parameters:
  ///   - context: is `ExecutionContext` to perform transform on.
  ///     Instance of context will be passed as the first argument to the transformation.
  ///     Transformation will not be executed if executor was deallocated before execution,
  ///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
  ///   - executor: is `Executor` to override executor provided by context
  ///   - transform: is block to execute on successful completion of original future.
  ///     Return from transformation block will cause returned future to complete successfuly.
  ///     Throw from transformation block will returned future to complete with failure
  ///   - strongContext: is `ExecutionContext` restored from weak reference of context passed to method
  ///   - Success: is a success value of original future
  /// - Returns: transformed future
  func map<T, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (_ strongContext: C, _ Success: Success) throws -> T
    ) -> Future<T>
  {
    // Test: FutureTests.testMapContextual_Success_ContextAlive
    // Test: FutureTests.testMapContextual_Success_ContextDead
    // Test: FutureTests.testMapContextual_Failure_ContextAlive
    // Test: FutureTests.testMapContextual_Failure_ContextDead
    return mapSuccess(context: context, executor: executor, transform)
  }

  /// Applies the transformation to the future and flattens future returned by transformation
  ///
  /// - Parameters:
  ///   - context: is `ExecutionContext` to perform transform on.
  ///     Instance of context will be passed as the first argument to the transformation.
  ///     Transformation will not be executed if executor was deallocated before execution,
  ///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
  ///   - executor: is `Executor` to override executor provided by context
  ///   - transform: is block to execute on successful completion of original future.
  ///     Return from transformation block will cause returned future to complete with future.
  ///     Throw from transformation block will returned future to complete with failure
  ///   - strongContext: is `ExecutionContext` restored from weak reference of context passed to method
  ///   - Success: is a success value of original future
  /// - Returns: transformed future
  func flatMap<T: Completing, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    transform: @escaping (_ strongContext: C, _ Success: Success) throws -> T
    ) -> Future<T.Success>
  {
    return flatMapSuccess(context: context, executor: executor, transform)
  }

  /// Applies the transformation to the future and flattens channel returned by transformation
  ///
  /// - Parameters:
  ///   - context: is `ExecutionContext` to perform transform on.
  ///     Instance of context will be passed as the first argument to the transformation.
  ///     Transformation will not be executed if executor was deallocated before execution,
  ///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
  ///   - executor: is `Executor` to override executor provided by context
  ///   - transform: is block to execute on successful completion of original channel.
  ///     Return from transformation block will cause returned channel to complete with channel.
  ///     Throw from transformation block will returned channel to complete with failure
  ///   - strongContext: is `ExecutionContext` restored from weak reference of context passed to method
  ///   - Success: is a success value of original future
  /// - Returns: transformed future
  func flatMap<T: Completing&Updating, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    transform: @escaping (_ strongContext: C, _ Success: Success) throws -> T
    ) -> Channel<T.Update, T.Success>
  {
    return flatMapSuccess(context: context, executor: executor, transform)
  }

  /// Makes future with delayed completion
  ///
  /// - Parameter timeout: is `Double` (seconds) to delay competion of original future with.
  /// - Returns: delayed future
  func delayed(timeout: Double) -> Future<Success>
  {
    return delayedCompletion(timeout: timeout)
  }
}

/// **Internal use only**
///
/// Each subscription to a future value will be expressed in such handler.
/// Future will accumulate handlers until completion or deallocacion.
public class FutureHandler<Success> {
  typealias Block = (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
  let executor: Executor
  let block: Block
  var owner: Future<Success>?

  init(executor: Executor,
       block: @escaping Block,
       owner: Future<Success>)
  {
    self.executor = executor
    self.block = block
    self.owner = owner
  }

  func handle(_ value: Fallible<Success>, from originalExecutor: Executor?) {
    self.executor.execute(from: originalExecutor) {
      (originalExecutor) in
      self.block(value, originalExecutor)
    }
  }

  func releaseOwner() {
    self.owner = nil
  }
}
