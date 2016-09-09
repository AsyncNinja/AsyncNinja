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

public protocol _Future : Consumable { // hacking type system
}

/// Future is a proxy of value that will be available at some point in the future.
public class Future<T> : _Future, ExecutionContext {
  public typealias Value = T
  typealias Handler = FutureHandler<Value>
  public var executor: Executor { return .immediate }
  public let releasePool = ReleasePool()

  init() { }

  /// Higher order function (method) that asynchronously transforms value of this future on specified executor
  /// "transform" closure is not thowable in this implementation because otherwise it would make returning future fallible.
  final public func map<T>(executor: Executor = .primary, _ transform: @escaping (Value) -> T) -> Future<T> {
    let promise = Promise<T>()
    weak var weakPromise = promise
    let handler = self._onValue(executor: executor) { weakPromise?.complete(with: transform($0)) }
    self.add(handler: handler)
    promise.releasePool.insert(self)
    return promise
  }

  final public func map<T>(executor: Executor = .primary, _ transform: @escaping (Value) throws -> T) -> FallibleFuture<T> {
    let promise = FalliblePromise<T>()
    weak var weakPromise = promise
    let handler = self._onValue(executor: executor) { value in
      weakPromise?.complete(with: fallible { try transform(value) })
    }
    self.add(handler: handler)
    promise.releasePool.insert(self)
    return promise
  }

  @discardableResult
  final func _onValue(executor: Executor, block: @escaping (Value) -> Void) -> Handler {
    let handler = Handler(executor: executor, block: block)
    self.add(handler: handler)
    return handler
  }

//  /// Higher order function (method) that asynchronously performs block on specified executor as soon as a value will be available.
//  /// This method is less preferrable then map because using of it means that block has sideeffects (does more then just data transformation).
//  final public func onValue(executor: Executor = .primary, block: @escaping (Value) -> Void) {
//    self.releasePool.insert(self._onValue(block: block))
//  }

  func add(handler: FutureHandler<Value>) {
    fatalError() // abstract
  }

  final public func wait(waitingBlock: (DispatchSemaphore) -> DispatchTimeoutResult) -> Value? {
    let sema = DispatchSemaphore(value: 0)
    var result: Value? = nil

    self._onValue(executor: .immediate) {
      result = $0
      sema.signal()
    }

    switch waitingBlock(sema) {
    case .success:
      return result
    case .timedOut:
      return nil
    }
  }
}

struct FutureHandler<T> {
  let executor: Executor
  let block: (T) -> Void

  init(executor: Executor, block: @escaping (T) -> Void) {
    self.executor = executor
    self.block = block
  }

  func handle(value: T) {
    self.executor.execute { self.block(value) }
  }
}
