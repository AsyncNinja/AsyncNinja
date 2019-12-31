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
  var isComplete: Bool { return completion.isSome }

  /// Shorthand property that returns success
  /// if `Completing` is completed with success or nil otherwise
  var success: Success? { return self.completion?.maybeSuccess }

  /// Shorthand property that returns failure value
  /// if `Completing` is completed with failure or nil otherwise
  var failure: Swift.Error? { return self.completion?.maybeFailure }
}

public extension Completing {
  /// Performs block when completion value.
  /// *This method is method is less preferable then `onComplete(context: ...)`.*
  ///
  /// - Parameters:
  ///   - executor: to call block on
  ///   - block: block to call on completion
  @discardableResult
  func onComplete(
    executor: Executor = .primary,
    _ block: @escaping (Fallible<Success>) -> Void
    ) -> Self {
    return _onComplete(executor: executor) { (completion, _) in
      block(completion)
    }
  }

  internal func _onComplete(
    executor: Executor = .primary,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> Self {
    let handler = makeCompletionHandler(
      executor: executor
    ) { (completion, originalExecutor) in
      block(completion, originalExecutor)
    }
    _asyncNinja_retainHandlerUntilFinalization(handler)
    return self
  }

  /// Performs block when competion becomes available.
  @discardableResult
  func onSuccess(
    executor: Executor = .primary,
    _ block: @escaping (Success) -> Void
    ) -> Self {
    return onComplete(executor: executor) { $0.onSuccess(block) }
  }

  /// Performs block when failure becomes available.
  @discardableResult
  func onFailure(
    executor: Executor = .primary,
    _ block: @escaping (Swift.Error) -> Void
    ) -> Self {
    return onComplete(executor: executor) { $0.onFailure(block) }
  }
}

public extension Completing {
  /// Performs block when completion value.
  /// This method is suitable for applying completion to context.
  ///
  /// - Parameters:
  ///   - context: to complete on
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - block: block to call on completion
  @discardableResult
  func onComplete<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ block: @escaping (C, Fallible<Success>) -> Void
    ) -> Self {
    // Test: FutureTests.testOnCompleteContextual_ContextAlive
    // Test: FutureTests.testOnCompleteContextual_ContextDead
    return _onComplete(
      context: context, executor: executor
    ) { (context, completion, _) in
      block(context, completion)
    }
  }

  @discardableResult
  internal func _onComplete<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ block: @escaping (_ context: C, _ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> Self {
    // Test: FutureTests.testOnCompleteContextual_ContextAlive
    // Test: FutureTests.testOnCompleteContextual_ContextDead
    let handler = makeCompletionHandler(
      executor: executor ?? context.executor
    ) { [weak context] (completion, originalExecutor) in
      if let context = context {
        block(context, completion, originalExecutor)
      }
    }

    if let handler = handler {
      context.releaseOnDeinit(handler)
    }

    return self
  }

  /// Performs block when completion becomes available.
  @discardableResult
  func onSuccess<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ block: @escaping (C, Success) -> Void
    ) -> Self {
    return onComplete(
      context: context,
      executor: executor
    ) { (context, completion) in
      switch completion {
      case let .success(success):
        block(context, success)
      case .failure:
        break
      }
    }
  }

  /// Performs block when failure becomes available.
  @discardableResult
  func onFailure<C: ExecutionContext>(
    context: C, executor: Executor? = nil,
    _ block: @escaping (C, Swift.Error) -> Void
    ) -> Self {
    return onComplete(context: context, executor: executor
    ) { (context, completion) in
      switch completion {
      case .success:
        break
      case let .failure(failure):
        block(context, failure)
      }
    }
  }
  
  @discardableResult
  func assignSuccess<T:ExecutionContext>(
    to keyPath: ReferenceWritableKeyPath<T, Success>,
    on context: T, executor: Executor? = nil
  ) -> Self {
    return onComplete(context: context, executor: executor
    ) { (context, completion) in
      switch completion {
      case .success(let success):
        context[keyPath: keyPath] = success
      default: break
      }
    }
  }
}

private func eternalWaiter(semaphore: DispatchSemaphore) -> DispatchTimeoutResult {
  semaphore.wait()
  return .success
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
    var result: Fallible<Success>?

    var handler = makeCompletionHandler(executor: .immediate) { (completion, _) in
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
    return wait(waitingBlock: eternalWaiter)!
  }

  /// Waits for future to complete and returns completion value
  ///
  /// - Parameter timeout: `DispatchTime` to wait completion for
  /// - Returns: completion value or nil if `Future` did not complete in specified timeout
  func wait(timeout: DispatchTime) -> Fallible<Success>? {
    return wait(waitingBlock: { $0.wait(timeout: timeout) })
  }

  /// Waits for future to complete and returns completion value
  ///
  /// - Parameter wallTimeout: `DispatchWallTime` to wait completion for
  /// - Returns: completion value or nil if `Future` did not complete in specified timeout
  func wait(wallTimeout: DispatchWallTime) -> Fallible<Success>? {
    return wait(waitingBlock: { $0.wait(wallTimeout: wallTimeout) })
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
