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

//  The combination of protocol _Future and abstract class Future
//  is an dirty hack of type system. But there are no higher-kinded types
//  or generic protocols to implement it properly.

public protocol _Future { // hacking type system
  associatedtype Value
  func _onValue(executor: Executor, block: @escaping (Value) -> Void) -> FutureHandler<Value>
}

/// Future is a proxy of value that will be available at some point in the future.
public class Future<T> : _Future {
  public typealias Value = T
  public typealias Handler = FutureHandler<Value>

  init() { }

  /// Higher order function (method) that asynchronously transforms value of this future on specified executor
  /// "transform" closure is not thowable in this implementation because otherwise it would make returning future fallible.


  // let futureB = futureA.map(transform)
  // futureA must live if (isIncomplete && hasSubscribers)
  final public func map<T>(executor: Executor = .primary, _ transform: @escaping (Value) -> T) -> Future<T> {
    let promise = Promise<T>()
    let handler = self._onValue(executor: executor) { [weak promise] in
      promise?.complete(with: transform($0))
    }
    self.add(handler: handler)
    promise.releasePool.insert(handler)
    return promise
  }

  final public func map<T>(executor: Executor = .primary, _ transform: @escaping (Value) throws -> T) -> FallibleFuture<T> {
    return self.map(executor: executor) { value in fallible { try transform(value) } }
  }

  final public func _onValue(executor: Executor, block: @escaping (Value) -> Void) -> Handler {
    let handler = Handler(executor: executor, block: block, owner: self)
    self.add(handler: handler)
    return handler
  }

  func add(handler: FutureHandler<Value>) {
    fatalError() // abstract
  }

  final public func wait(waitingBlock: (DispatchSemaphore) -> DispatchTimeoutResult) -> Value? {
    let sema = DispatchSemaphore(value: 0)
    var result: Value? = nil

    var handler: Handler? = self._onValue(executor: .immediate) {
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

  final public func wait() -> Value {
    return self.wait(waitingBlock: { $0.wait(); return .success })!
  }

  final public func wait(timeout: DispatchTime) -> Value? {
    return self.wait(waitingBlock: { $0.wait(timeout: timeout) })
  }

  final public func wait(wallTimeout: DispatchWallTime) -> Value? {
    return self.wait(waitingBlock: { $0.wait(wallTimeout: wallTimeout) })
  }
}

public class FutureHandler<T> {
  let executor: Executor
  let block: (T) -> Void
  let owner: Future<T>

  init(executor: Executor, block: @escaping (T) -> Void, owner: Future<T>) {
    self.executor = executor
    self.block = block
    self.owner = owner
  }

  func handle(value: T) {
    self.executor.execute { self.block(value) }
  }
}


extension Future where T : _Future {

  /// flatterns combination of two unfaillable futures to a signle unfallible one
  public func flattern() -> Future<T.Value> {
    let promise = Promise<T.Value>()

    let handler = self._onValue(executor: .immediate) { [weak promise] (future) in
      guard let promise = promise else { return }
      let handler = future._onValue(executor: .immediate) { [weak promise] (value) in
        promise?.complete(with: value)
      }
      promise.releasePool.insert(handler)
    }

    promise.releasePool.insert(handler)

    return promise
  }
}


extension Future where T : _Fallible, T.Success : _Future {

  /// flatterns combination of fallible and unfaillable futures to a signle fallible one
  public func flattern() -> FallibleFuture<T.Success.Value> {
    let promise = FalliblePromise<T.Success.Value>()

    let handler = self._onValue(executor: .immediate) { [weak promise] (futureFallible) in
      guard let promise = promise else { return }
      futureFallible.onFailure(promise.fail(with:))
      futureFallible.onSuccess { future in
        let handler = future._onValue(executor: .immediate) { [weak promise] (value: T.Success.Value) -> Void in
          promise?.succeed(with: value)
        }
        promise.releasePool.insert(handler)
      }
    }

    promise.releasePool.insert(handler)
    return promise
  }
}

extension Future where T : _Fallible, T.Success : _Future, T.Success.Value : _Fallible {

  /// flatterns combination of two faillable futures to a signle fallible one
  public func flattern() -> Future<T.Success.Value> {
    let promise = Promise<T.Success.Value>()

    let handler = self._onValue(executor: .immediate) { [weak promise] (futureFallible) in
      guard let promise = promise else { return }
      futureFallible.onFailure(promise.fail(with:))
      futureFallible.onSuccess { future in
        let handler = future._onValue(executor: .immediate) { [weak promise] (value: T.Success.Value) -> Void in
          promise?.complete(with: value)
        }
        promise.releasePool.insert(handler)
      }
    }

    promise.releasePool.insert(handler)
    return promise
  }
}
