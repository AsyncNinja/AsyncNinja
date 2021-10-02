//
//  Copyright (c) 2016-2017 Anton Mironov
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

// MARK: - asyncMap

public extension Sequence {

  /// Asyncronously transforms each element of the Sequence
  ///
  /// - Parameters:
  ///   - executor: to perform transform on
  ///   - transform: transformation to perform
  ///   - element: to transform
  /// - Returns: a Future of Array of results
  func asyncMap<T>(
    executor: Executor = .primary,
    _ transform: @escaping (_ element: Self.Iterator.Element) throws -> T
    ) -> Future<[T]> {
    return _asyncMap(executor: executor, transform)
  }

  /// Asyncronously transforms each element of the Sequence
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - transform: transformation to perform
  ///   - element: to transform
  /// - Returns: a Future of Array of results
  func asyncMap<T, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (_ strongContext: C, _ element: Self.Iterator.Element) throws -> T
    ) -> Future<[T]> {
    let promise = _asyncMap(
      executor: executor ?? context.executor
    ) { [weak context] (value) -> T in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, value)
    }

    context.addDependent(completable: promise)
    return promise
  }

  /// **internal use only**
  func _asyncMap<T>(
    executor: Executor = .primary,
    _ transform: @escaping (_ element: Self.Iterator.Element) throws -> T
    ) -> Promise<[T]> {
    func makeDummy(value: Self.Iterator.Element) -> T? {
      return nil
    }
    var subvalues: [T?] = self.map(makeDummy)
    let promise = Promise<[T]>()
    guard !subvalues.isEmpty else {
      promise.succeed([])
      return promise
    }
    let locking = makeLocking()
    var canContinue = true
    var unknownSubvaluesCount = subvalues.count

    func updateAndTest(index: Int, value: T) -> [T]? {
      locking.lock()
      defer { locking.unlock() }
      subvalues[index] = value
      unknownSubvaluesCount -= 1
      guard 0 == unknownSubvaluesCount else { return nil }
      return subvalues.map { $0! }
    }

    for (index, value) in self.enumerated() {
      executor.execute(
        from: nil
      ) { [weak promise] (originalExecutor) in
        guard case .some = promise, canContinue else { return }

        do {
          let subvalue = try transform(value)
          if canContinue, let success = updateAndTest(index: index, value: subvalue) {
            promise?.succeed(success, from: originalExecutor)
          }
        } catch {
          promise?.fail(error, from: originalExecutor)
          canContinue = false
          return
        }
      }
    }

    promise._asyncNinja_notifyFinalization {
      canContinue = false
    }

    return promise
  }
}
