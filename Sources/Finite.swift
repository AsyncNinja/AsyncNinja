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

  /// **internal use only**
  func makeFinalHandler(executor: Executor,
                        block: @escaping (FinalValue) -> Void) -> FinalHandler?
}

/// Each of these methods transform one future into another.
///
/// Returned future will own self until it`s completion.
/// Use this method only for **pure** transformations (not changing shared state).
/// Use methods map(context:executor:transform:) for state changing transformations.
public extension Finite {
  /// Transforms Finite<TypeA> => Future<TypeB>
  func mapFinal<T>(executor: Executor = .primary,
                transform: @escaping (FinalValue) -> T) -> Future<T> {
    let promise = Promise<T>()
    let handler = self.makeFinalHandler(executor: executor) { [weak promise] (final) -> Void in
      guard let promise = promise else { return }
      promise.complete(with: transform(final))
    }
    if let handler = handler {
      promise.insertToReleasePool(handler)
    }
    return promise
  }

  /// Transforms Future<TypeA> => FallibleFuture<TypeB>
  func mapFinal<T>(executor: Executor = .primary,
                transform: @escaping (FinalValue) throws -> T) -> FallibleFuture<T> {
    return self.mapFinal(executor: executor) { final in fallible { try transform(final) } }
  }
}

public extension Finite {
  func mapFinal<U: ExecutionContext, V>(context: U, executor: Executor? = nil,
                transform: @escaping (U, FinalValue) throws -> V) -> FallibleFuture<V> {
    return self.mapFinal(executor: executor ?? context.executor) { [weak context] (final) -> V in
      guard let context = context
        else { throw ConcurrencyError.contextDeallocated }
      return try transform(context, final)
    }
  }

  func onFinal<U: ExecutionContext>(context: U, executor: Executor? = nil,
               block: @escaping (U, FinalValue) -> Void) {
    let handler = self.makeFinalHandler(executor: executor ?? context.executor) { [weak context] (final) in
      guard let context = context
        else { return }
      block(context, final)
    }

    if let handler = handler {
      context.releaseOnDeinit(handler)
    }
  }
}

/// Each of these methods synchronously awaits for future to complete.
/// Using this method is **strongly** discouraged. Calling it on the same serial queue
/// as any code performed on the same queue this future depends on will cause deadlock.
public extension Finite {
  func wait(waitingBlock: (DispatchSemaphore) -> DispatchTimeoutResult) -> FinalValue? {
    let sema = DispatchSemaphore(value: 0)
    var result: FinalValue? = nil

    var handler = self.makeFinalHandler(executor: .immediate) {
      result = $0
      sema.signal()
    }
    defer { handler = nil }

    switch waitingBlock(sema) {
    case .success:
      return result
    case .timedOut:
      return nil
    }
  }

  func wait() -> FinalValue {
    return self.wait(waitingBlock: { $0.wait(); return .success })!
  }

  func wait(timeout: DispatchTime) -> FinalValue? {
    return self.wait(waitingBlock: { $0.wait(timeout: timeout) })
  }

  func wait(wallTimeout: DispatchWallTime) -> FinalValue? {
    return self.wait(waitingBlock: { $0.wait(wallTimeout: wallTimeout) })
  }
}

public extension Finite {
  func delayedFinal(timeout: Double) -> Future<FinalValue> {
    let promise = Promise<FinalValue>()
    let handler = self.makeFinalHandler(executor: .immediate) { [weak promise] (value) in
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

public extension Finite where FinalValue : _Fallible {
  func mapFinal<T>(executor: Executor = .primary,
                transform: @escaping (FinalValue) throws -> T) -> FallibleFuture<T> {
    return self.mapFinal(executor: executor) { final -> Fallible<T> in
      fallible { try transform(final) }
    }
  }

  func mapFinal<T, U: ExecutionContext>(context: U, executor: Executor? = nil,
                transform: @escaping (U, FinalValue) throws -> T) -> FallibleFuture<T> {
    return self.mapFinal(context: context, executor: executor) { (context, final) -> T in
      try transform(context, final)
    }
  }

  func mapSuccess<T>(executor: Executor = .primary,
                  transform: @escaping (FinalValue.Success) throws -> T) -> FallibleFuture<T> {
    return self.mapFinal(executor: executor) { $0.mapSuccess(transform: transform) }
  }

  func mapFailure(executor: Executor = .primary,
                  transform: @escaping (Error) -> FinalValue.Success) -> Future<FinalValue.Success> {
    return self.mapFinal(executor: executor) { $0.mapFailure(transform: transform) }
  }

  func mapFailure(executor: Executor = .primary,
                  transform: @escaping (Error) throws -> FinalValue.Success) -> FallibleFuture<FinalValue.Success> {
    return self.mapFinal(executor: executor) { $0.mapFailure(transform: transform) }
  }
}

public extension Finite where FinalValue : _Fallible {
  final public func mapSuccess<T, U: ExecutionContext>(context: U, executor: Executor? = nil,
                               transform: @escaping (U, FinalValue.Success) throws -> T) -> FallibleFuture<T> {
    return self.mapFinal(context: context, executor: executor) { (context, value) -> T in
      let success = try value.liftSuccess()
      return try transform(context, success)
    }
  }

  final public func onSuccess<U: ExecutionContext>(context: U, executor: Executor? = nil,
                              block: @escaping (U, FinalValue.Success) -> Void) {
    self.onFinal(context: context, executor: executor) { (context, value) in
      guard let success = value.success else { return }
      block(context, success)
    }
  }

  final public func mapFailure<U: ExecutionContext>(context: U, executor: Executor? = nil,
                               transform: @escaping (U, Error) throws -> FinalValue.Success) -> FallibleFuture<FinalValue.Success> {
    return self.mapFinal(context: context, executor: executor) { (context, value) -> FinalValue.Success in
      if let failure = value.failure { return try transform(context, failure) }
      if let success = value.success { return success }
      fatalError()
    }
  }

  final public func onFailure<U: ExecutionContext>(context: U, executor: Executor? = nil,
                              block: @escaping (U, Error) -> Void) {
    self.onFinal(context: context, executor: executor) { (context, value) in
      guard let failure = value.failure else { return }
      block(context, failure)
    }
  }
}
