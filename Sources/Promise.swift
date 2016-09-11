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

/// Promise that may be manually completed by owner.
final public class Promise<T> : MutableFuture<T> {
  override public init() { }

  /// Completes promise with value and returns true.
  /// Returns false if promise was completed before.
  @discardableResult
  final public func complete(with value: Value) -> Bool {
    return self.tryComplete(with: value)
  }

  /// Completes promise when specified future completes.
  /// `self` will retain specified future until it`s completion
  @discardableResult
  final public func complete(with future: Future<Value>) {
    let handler = future._onValue(executor: .immediate) { [weak self] in
      self?.tryComplete(with: $0)
    }
    self.releasePool.insert(handler)
  }
}

/// Asynchrounously executes block on executor and wraps returned value into future
public func future<T>(executor: Executor, block: @escaping () -> T) -> Future<T> {
  let promise = Promise<T>()
  executor.execute { [weak promise] in promise?.complete(with: block()) }
  return promise
}

/// Asynchrounously executes block on executor and wraps returned value into future
public func future<T>(executor: Executor, block: @escaping () throws -> T) -> FallibleFuture<T> {
  return future(executor: executor) { fallible(block: block) }
}

/// Asynchrounously executes block after timeout on executor and wraps returned value into future
public func future<T>(executor: Executor = .primary, after timeout: Double, block: @escaping () -> T) -> Future<T> {
  let promise = Promise<T>()
  executor.execute(after: timeout) { [weak promise] in
    guard let promise = promise else { return }
    promise.complete(with: block())
  }
  return promise
}

/// Asynchrounously executes block after timeout on executor and wraps returned value into future
public func future<T>(after timeout: Double, block: @escaping () throws -> T) -> FallibleFuture<T> {
  return future(after: timeout) { fallible(block: block) }
}
