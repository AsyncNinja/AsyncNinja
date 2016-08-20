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

public typealias FailableFuture<T> = Future<Failable<T>>
typealias FailablePromise<T> = Promise<Failable<T>>

public extension Future where T : _Failable {

  public typealias Success = Value.Success

  final public func map<T>(executor: Executor = .primary, _ transform: @escaping (Value) throws -> T) -> FailableFuture<T> {
    let promise = FailablePromise<T>()
    let handler = FutureHandler(executor: executor) { value in
      promise.complete(with: failable { try transform(value) })
    }
    self.add(handler: handler)
    return promise
  }

  final public func liftSuccess<T>(executor: Executor, transform: @escaping (Success) throws -> T) -> FailableFuture<T> {
    let promise = FailablePromise<T>()
    self.onValue(executor: executor) {
      promise.complete(with: $0.liftSuccess(transform: transform))
    }
    return promise
  }

  final public func liftFailure(executor: Executor, transform: @escaping (Error) -> Success) -> Future<Success> {
    let promise = Promise<Success>()
    self.onValue(executor: executor) { value -> Void in
      let nextValue = value.liftFailure(transform: transform)
      promise.complete(with: nextValue)
    }
    return promise
  }

  final public func liftFailure(executor: Executor, transform: @escaping (Error) throws -> Success) -> FailableFuture<Success> {
    let promise = FailablePromise<Success>()
    self.onValue(executor: executor) { value -> Void in
      let nextValue = value.liftFailure(transform: transform)
      promise.complete(with: nextValue)
    }
    return promise
  }
}
