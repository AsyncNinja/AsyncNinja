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

public class Promise<T> : MutableFuture<T> {
  override public init() { }

  @discardableResult
  final public func complete(with value: Value) -> Bool {
    return self.tryComplete(with: value)
  }

  @discardableResult
  final public func complete(with future: Future<Value>) {
    let handler = future._onValue(executor: .immediate) { [weak self] in
      self?.tryComplete(with: $0)
    }
    self.releasePool.insert(handler)
  }

}

public func future<T>(executor: Executor, block: @escaping () -> T) -> Future<T> {
  let promise = Promise<T>()
  executor.execute { [weak promise] in promise?.complete(with: block()) }
  return promise
}

public func future<T>(executor: Executor, block: @escaping () -> Future<T>) -> Future<T> {
  return future(executor: executor, block: block).flattern()
}

public func future<T>(executor: Executor, block: @escaping () throws -> T) -> FallibleFuture<T> {
  let promise = Promise<Fallible<T>>()
  executor.execute { [weak promise] in promise?.complete(with: fallible(block: block)) }
  return promise
}

public func future<T>(executor: Executor, block: @escaping () throws -> Future<T>) -> FallibleFuture<T> {
  return future(executor: executor, block: block).flattern()
}

public func future<T>(executor: Executor, block: @escaping () throws -> FallibleFuture<T>) -> FallibleFuture<T> {
  return future(executor: executor, block: block).flattern()
}

public func future<T>(after timeout: TimeInterval, value: T) -> Future<T> {
  let promise = Promise<T>()
  let deadline = DispatchWallTime.now() + .nanoseconds(Int(timeout * 1000 * 1000 * 1000))
  DispatchQueue.global(qos: .default).asyncAfter(wallDeadline: deadline) {
    promise.complete(with: value)
  }
  return promise
}
