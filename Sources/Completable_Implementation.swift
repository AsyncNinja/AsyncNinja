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

public extension Completable {

  /// Completes completable when specified completing completes.
  /// `self` will retain specified future until it`s completion
  func complete<T: Completing>(with completing: T) where T.Success == Success {
    let handler = completing.makeCompletionHandler(
      executor: .immediate
    ) { [weak self] (completion, originalExecutor) in
      self?.complete(completion, from: originalExecutor)
    }
    _asyncNinja_retainHandlerUntilFinalization(handler)
  }

  /// Shorthand to tryComplete(with:) that does not return value
  ///
  /// - Parameter completion: value to compete `Completing` with
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  func complete(_ completion: Fallible<Success>, from originalExecutor: Executor?) {
    tryComplete(completion, from: originalExecutor)
  }

  /// Shorthand to tryComplete(with:) that does not return value
  ///
  /// - Parameter completion: value to compete `Completing` with
  func complete(_ completion: Fallible<Success>) {
    tryComplete(completion, from: nil)
  }

  /// Tries to complete self with success
  ///
  /// - Parameter success: value to succeed `Completing` with
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  /// - Returns: true if this call completed `Completable`
  @discardableResult
  func trySucceed(_ success: Success, from originalExecutor: Executor? = nil) -> Bool {
    return tryComplete(Fallible(success: success), from: originalExecutor)
  }

  /// Shorthand to trySucceed(with:) that does not return value
  ///
  /// - Parameter success: value to succeed `Completing` with
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  func succeed(_ success: Success, from originalExecutor: Executor?) {
    complete(Fallible(success: success), from: originalExecutor)
  }

  /// Shorthand to trySucceed(with:) that does not return value
  ///
  /// - Parameter success: value to succeed `Completing` with
  func succeed(_ success: Success) {
    complete(Fallible(success: success))
  }

  /// Tries to complete self with failure vlue
  ///
  /// - Parameter failure: error to fail `Completing` with
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  /// - Returns: true if this call completed `Completable`
  @discardableResult
  public func tryFail(_ failure: Swift.Error, from originalExecutor: Executor? = nil) -> Bool {
    return tryComplete(Fallible(failure: failure), from: originalExecutor)
  }

  /// Shorthand to tryFail(with:) that does not return value
  ///
  /// - Parameter failure: error to fail `Completing` with
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  public func fail(_ failure: Swift.Error, from originalExecutor: Executor?) {
    complete(Fallible(failure: failure), from: originalExecutor)
  }

  /// Shorthand to tryFail(with:) that does not return value
  ///
  /// - Parameter failure: error to fail `Completing` with
  public func fail(_ failure: Swift.Error) {
    complete(Fallible(failure: failure))
  }

  /// Completes with cancellation (AsyncNinjaError.cancelled)
  public func cancel() {
    fail(AsyncNinjaError.cancelled)
  }

  /// Completes with cancellation (AsyncNinjaError.cancelled)
  ///
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  public func cancel(from originalExecutor: Executor?) {
    fail(AsyncNinjaError.cancelled, from: originalExecutor)
  }

  /// Completes with error of deallocated context (AsyncNinjaError.contextDeallocated)
  ///
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  func cancelBecauseOfDeallocatedContext(from originalExecutor: Executor?) {
    fail(AsyncNinjaError.contextDeallocated, from: originalExecutor)
  }

  /// Completes with error of deallocated context (AsyncNinjaError.contextDeallocated)
  ///
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  func cancelBecauseOfDeallocatedContext() {
    fail(AsyncNinjaError.contextDeallocated)
  }
}

extension Completable where Success == Void {

  /// Convenience method succeeds mutable with void value
  ///
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  public func succeed(from originalExecutor: Executor? = nil) {
    succeed((), from: originalExecutor)
  }
}

public extension Completable where Success: AsyncNinjaOptionalAdaptor {
  /// Completes promise when specified future completes.
  /// `self` will retain specified future until it`s completion
  func complete<T: Completing>(with completing: T) where T.Success == Success.AsyncNinjaWrapped {
    let handler = completing.makeCompletionHandler(
      executor: .immediate
    ) { [weak self] (completion, originalExecutor) in
      switch completion {
      case .success(let success):
        self?.succeed(Success(asyncNinjaOptionalValue: success), from: originalExecutor)
      case .failure(let failure):
        self?.fail(failure, from: originalExecutor)
      }
    }
    _asyncNinja_retainHandlerUntilFinalization(handler)
  }
}
