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

public extension Future {
  
  final func map<U: ExecutionContext, V>(context: U?, executor: Executor? = nil, _ transform: @escaping (Value, U) throws -> V) -> FallibleFuture<V> {
    guard let context = context
      else { return future(failure: ConcurrencyError.contextDeallocated) }
    return self.map(executor: executor ?? context.executor) { [weak context] (value) in
      guard let context = context
        else { throw ConcurrencyError.contextDeallocated }
      return try transform(value, context)
    }
  }

  final func onValue<U: ExecutionContext>(context: U?, executor: Executor? = nil, block: @escaping (Value, U) -> Void) {
    guard let context = context
      else { return }

    let handler = self._onValue(executor: executor ?? context.executor) { [weak context] (value) in
      guard let context = context
        else { return }
      block(value, context)
    }

    context.releasePool.insert(handler)
  }
}

public extension Future where T : _Fallible {

  final public func liftSuccess<T, U: ExecutionContext>(context: U?, executor: Executor? = nil, transform: @escaping (Success, U) throws -> T) -> FallibleFuture<T> {
    return self.map(context: context, executor: executor) { (value, context) in
      if let failureValue = value.failureValue { throw failureValue }
      if let successValue = value.successValue { return try transform(successValue, context) }
      fatalError()
    }
  }

  final public func onSuccess<U: ExecutionContext>(context: U?, executor: Executor? = nil, block: @escaping (Success, U) -> Void) {
    self.onValue(context: context, executor: executor) { (value, context) in
      guard let successValue = value.successValue else { return }
      block(successValue, context)
    }
  }

  final public func liftFailure<U: ExecutionContext>(context: U?, executor: Executor? = nil, transform: @escaping (Error, U) throws -> Success) -> FallibleFuture<Success> {
    return self.map(context: context, executor: executor) { (value, context) in
      if let failureValue = value.failureValue { return try transform(failureValue, context) }
      if let successValue = value.successValue { return successValue }
      fatalError()
    }
  }

  final public func onFailure<U: ExecutionContext>(context: U?, executor: Executor? = nil, block: @escaping (Error, U) -> Void) {
    self.onValue(context: context, executor: executor) { (value, context) in
      guard let failureValue = value.failureValue else { return }
      block(failureValue, context)
    }
  }
}

//public func future<T>(context: ExecutionContext, block: @escaping () -> T) -> Future<T> {
//  let promise = Promise<T>()
//  context.executor.execute { promise.complete(with: block()) }
//  return promise
//}

public func future<T, U : ExecutionContext>(context: U?, block: @escaping (U) throws -> T) -> FallibleFuture<T> {
  guard let context = context
    else { return future(failure: ConcurrencyError.contextDeallocated) }

  return future(executor: context.executor) { [weak context] () -> T in
    guard let context = context
      else { throw ConcurrencyError.contextDeallocated }

    return try block(context)
  }
}

public func future<T, U : ExecutionContext>(context: U?, block: @escaping (U) throws -> Future<T>) -> FallibleFuture<T> {
  guard let context = context
    else { return future(failure: ConcurrencyError.contextDeallocated) }

  return future(executor: context.executor) { [weak context] () -> Future<T>  in
    guard let context = context
      else { throw ConcurrencyError.contextDeallocated }

    return try block(context)
  }
}

public func future<T, U : ExecutionContext>(context: U?, block: @escaping (U) throws -> FallibleFuture<T>) -> FallibleFuture<T> {
  guard let context = context
    else { return future(failure: ConcurrencyError.contextDeallocated) }

  return future(executor: context.executor) { [weak context] () -> FallibleFuture<T>  in
    guard let context = context
      else { throw ConcurrencyError.contextDeallocated }

    return try block(context)
  }
}
