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

public extension Future {
  
  final func map<U: ExecutionContext, V>(context: U, executor: Executor? = nil, _ transform: @escaping (U, Value) throws -> V) -> FallibleFuture<V> {
    return self.map(executor: executor ?? context.executor) { [weak context] (value) -> V in
      guard let context = context
        else { throw ConcurrencyError.contextDeallocated }
      return try transform(context, value)
    }
  }

  final func onValue<U: ExecutionContext>(context: U, executor: Executor? = nil, block: @escaping (U, Value) -> Void) {
    let handler = self._onValue(executor: executor ?? context.executor) { [weak context] (value) in
      guard let context = context
        else { return }
      block(context, value)
    }

    context.releaseOnDeinit(handler)
  }
}

public extension Future where T : _Fallible {

  final public func liftSuccess<T, U: ExecutionContext>(context: U, executor: Executor? = nil, transform: @escaping (U, Success) throws -> T) -> FallibleFuture<T> {
    return self.map(context: context, executor: executor) { (context, value) -> T in
      if let failureValue = value.failureValue { throw failureValue }
      if let successValue = value.successValue { return try transform(context, successValue) }
      fatalError()
    }
  }

  final public func onSuccess<U: ExecutionContext>(context: U, executor: Executor? = nil, block: @escaping (U, Success) -> Void) {
    self.onValue(context: context, executor: executor) { (context, value) in
      guard let successValue = value.successValue else { return }
      block(context, successValue)
    }
  }

  final public func liftFailure<U: ExecutionContext>(context: U, executor: Executor? = nil, transform: @escaping (U, Error) throws -> Success) -> FallibleFuture<Success> {
    return self.map(context: context, executor: executor) { (context, value) -> Success in
      if let failureValue = value.failureValue { return try transform(context, failureValue) }
      if let successValue = value.successValue { return successValue }
      fatalError()
    }
  }

  final public func onFailure<U: ExecutionContext>(context: U, executor: Executor? = nil, block: @escaping (U, Error) -> Void) {
    self.onValue(context: context, executor: executor) { (context, value) in
      guard let failureValue = value.failureValue else { return }
      block(context, failureValue)
    }
  }
}

public func future<T, U : ExecutionContext>(context: U, executor: Executor? = nil, block: @escaping (U) throws -> T) -> FallibleFuture<T> {
  return future(executor: executor ?? context.executor) { [weak context] () -> T in
    guard let context = context
      else { throw ConcurrencyError.contextDeallocated }

    return try block(context)
  }
}
