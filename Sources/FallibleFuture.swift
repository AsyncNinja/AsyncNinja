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

import Foundation

public typealias FallibleFuture<T> = Future<Fallible<T>>
public typealias FalliblePromise<T> = Promise<Fallible<T>>

public extension Future where T : _Fallible {

  public typealias Success = Value.Success

  final public func map<T>(executor: Executor = .primary, _ transform: @escaping (Value) throws -> T) -> FallibleFuture<T> {
    let promise = FalliblePromise<T>()
    let handler = FutureHandler(executor: executor) { value in
      promise.complete(with: fallible { try transform(value) })
    }
    self.add(handler: handler)
    return promise
  }

  final public func liftSuccess<T>(executor: Executor, transform: @escaping (Success) throws -> T) -> FallibleFuture<T> {
    let promise = FalliblePromise<T>()
    self.onValue(executor: executor) {
      promise.complete(with: $0.liftSuccess(transform: transform))
    }
    return promise
  }
  
  final public func onSuccess(executor: Executor, block: @escaping (Success) -> Void) {
    self.onValue(executor: executor) {
      if let successValue = $0.successValue {
        block(successValue)
      }
    }
  }

  final public func liftFailure(executor: Executor, transform: @escaping (Error) -> Success) -> Future<Success> {
    let promise = Promise<Success>()
    self.onValue(executor: executor) { value -> Void in
      let nextValue = value.liftFailure(transform: transform)
      promise.complete(with: nextValue)
    }
    return promise
  }

  final public func liftFailure(executor: Executor, transform: @escaping (Error) throws -> Success) -> FallibleFuture<Success> {
    let promise = FalliblePromise<Success>()
    self.onValue(executor: executor) { value -> Void in
      let nextValue = value.liftFailure(transform: transform)
      promise.complete(with: nextValue)
    }
    return promise
  }
  
  final public func onFailure(executor: Executor, block: @escaping (Error) -> Void) {
    self.onValue(executor: executor) { value -> Void in
      if let failureValue = value.failureValue {
        block(failureValue)
      }
    }
  }
}

public extension Promise where T : _Fallible {
    final public func succeed(with success: Success) {
        self.complete(with: T(success: success))
    }
    
    final public func fail(with failure: Error) {
        self.complete(with: T(failure: failure))
    }
    
    final public func cancel() {
        self.fail(with: ConcurrencyError.cancelled)
    }
}

public func fallible<T>(_ future: Future<T>) -> FallibleFuture<T> {
  return future.map(executor: .immediate) { $0 }
}
