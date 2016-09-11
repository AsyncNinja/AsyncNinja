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

/// Future is a proxy of value that will be available at some point in the future.
public class Future<T> : _Future {
  public typealias Value = T
  public typealias Handler = FutureHandler<Value>

  /// Base future is **abstract**.
  ///
  /// Use `Promise` or `future(executor:block)` or `future(context:executor:block)` to make future.
  init() { }

  /// **Internal use only**.
  /// Makes handler with block. Memory management of returned handle is on you.
  final public func _onValue(executor: Executor, block: @escaping (Value) -> Void) -> Handler {
    let handler = Handler(executor: executor, block: block, owner: self)
    self.add(handler: handler)
    return handler
  }

  /// **Internal use only**.
  func add(handler: FutureHandler<Value>) {
    fatalError() // abstract
  }
}

/// Each of these methods transform one future into another.
///
/// Returned future will own self until it`s completion.
/// Use this method only for **pure** transformations (not changing shared state).
/// Use methods map(context:executor:transform:) for state changing transformations.
public extension Future {
  /// Transforms Future<TypeA> => Future<TypeB>
  final func map<T>(executor: Executor = .primary, transform: @escaping (Value) -> T) -> Future<T> {
    let promise = Promise<T>()
    let handler = self._onValue(executor: executor) { [weak promise] in
      promise?.complete(with: transform($0))
    }
    self.add(handler: handler)
    promise.releasePool.insert(handler)
    return promise
  }

  /// Transforms Future<TypeA> => FallibleFuture<TypeB>
  final func map<T>(executor: Executor = .primary, transform: @escaping (Value) throws -> T) -> FallibleFuture<T> {
    return self.map(executor: executor) { value in fallible { try transform(value) } }
  }
}

/// Each of these methods synchronously awaits for future to complete.
/// Using this method is **strongly** discouraged. Calling it on the same serial queue
/// as any code performed on the same queue this future depends on will cause deadlock.
public extension Future {
  final func wait(waitingBlock: (DispatchSemaphore) -> DispatchTimeoutResult) -> Value? {
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

  final func wait() -> Value {
    return self.wait(waitingBlock: { $0.wait(); return .success })!
  }

  final func wait(timeout: DispatchTime) -> Value? {
    return self.wait(waitingBlock: { $0.wait(timeout: timeout) })
  }

  final func wait(wallTimeout: DispatchWallTime) -> Value? {
    return self.wait(waitingBlock: { $0.wait(wallTimeout: wallTimeout) })
  }
}

/// **Internal use only**
///
/// Each subscription to a future value will be expressed in such handler.
/// Future will accumulate handlers until completion or deallocacion.
final public class FutureHandler<T> {
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

/// **Internal use only**
///
///  The combination of protocol _Future and abstract class Future
///  is an dirty hack of type system. But there are no higher-kinded types
///  or generic protocols to implement it properly.
public protocol _Future { // hacking type system
  associatedtype Value
  func _onValue(executor: Executor, block: @escaping (Value) -> Void) -> FutureHandler<Value>
}
