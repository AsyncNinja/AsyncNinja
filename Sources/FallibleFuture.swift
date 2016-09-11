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

public typealias FallibleFuture<T> = Future<Fallible<T>>
public typealias FalliblePromise<T> = Promise<Fallible<T>>

public extension Future where T : _Fallible {

  public typealias Success = Value.Success

  final public func map<T>(executor: Executor = .primary, _ transform: @escaping (Value) throws -> T) -> FallibleFuture<T> {
    return self.map(executor: executor) { value -> Fallible<T> in
      fallible { try transform(value) }
    }
  }

  final public func liftSuccess<T>(executor: Executor, transform: @escaping (Success) throws -> T) -> FallibleFuture<T> {
    return self.map(executor: executor) { $0.liftSuccess(transform: transform) }
  }
  
  final public func liftFailure(executor: Executor, transform: @escaping (Error) -> Success) -> Future<Success> {
    return self.map(executor: executor) { $0.liftFailure(transform: transform) }
  }

  final public func liftFailure(executor: Executor, transform: @escaping (Error) throws -> Success) -> FallibleFuture<Success> {
    return self.map(executor: executor) { $0.liftFailure(transform: transform) }
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
