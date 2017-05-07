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

// MARK: - asyncFlatMap

public extension Sequence {

  /// Asyncronously transforms each element of the Sequence
  /// with a transform that returns Completing.
  ///
  /// - Parameters:
  ///   - executor: to perform transform on
  ///   - transform: transformation to perform
  ///   - element: to transform
  /// - Returns: a Future of Array of results
  func asyncFlatMap<T: Completing>(
    executor: Executor = .primary,
    _ transform: @escaping (_ element: Self.Iterator.Element) throws -> T
    ) -> Future<[T.Success]> {
    return _asyncFlatMap(executor: executor, transform)
  }

  /// Asyncronously transforms each element of the Sequence
  /// with a transform that returns Completing.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - transform: transformation to perform
  ///   - element: to transform
  /// - Returns: a Future of Array of results
  func asyncFlatMap<T: Completing, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (_ strongContext: C, _ element: Self.Iterator.Element) throws -> T
    ) -> Future<[T.Success]> {
    let executor_ = executor ?? context.executor
    let future = _asyncFlatMap(
      executor: executor_
    ) { [weak context] (value) -> T in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, value)
    }

    if let promise = future as? Promise<[T.Success]> {
      context.addDependent(completable: promise)
    }

    return future
  }

  /// **internal use only**
  internal func _asyncFlatMap<T: Completing>(
    executor: Executor,
    _ transform: @escaping (_ element: Self.Iterator.Element) throws -> T
    ) -> Future<[T.Success]> {

    var subvalues: [T.Success?] = self.map { _ in nil }
    guard !subvalues.isEmpty else {
      return .just([])
    }

    let promise = Promise<[T.Success]>()
    var locking = makeLocking()
    var canContinue = true
    promise._asyncNinja_notifyFinalization { canContinue = false }
    var unknownSubvaluesCount = subvalues.count

    for (index, value) in enumerated() {
      executor.execute(
        from: nil
      ) { [weak promise] (originalExecutor) in
        guard case .some = promise, canContinue else { return }

        func updateAndTest(index: Int, subvalue: Fallible<T.Success>) -> Fallible<[T.Success]>? {
          switch subvalue {
          case let .success(success):
            subvalues[index] = success
            unknownSubvaluesCount -= 1
            assert(unknownSubvaluesCount >= 0)
            return 0 == unknownSubvaluesCount ? .success(subvalues.map { $0! }) : nil
          case let .failure(failure):
            canContinue = false
            return .failure(failure)
          }
        }

        do {
          let futureSubvalue: T = try transform(value)
          let handler = futureSubvalue.makeCompletionHandler(
            executor: .immediate
          ) { [weak promise] (subvalue, originalExecutor) in
            if let promise = promise, canContinue,
              let completion = locking.locker(index, subvalue, updateAndTest) {
              promise.complete(completion, from: originalExecutor)
            }
          }
          promise?._asyncNinja_retainHandlerUntilFinalization(handler)
        } catch {
          promise?.fail(error, from: originalExecutor)
          canContinue = false
        }
      }
    }

    return promise
  }
}

// MARK: - joined

public extension Sequence where Self.Iterator.Element: Completing {

  /// joins a Sequence of Completing to a Future of Array
  func joined() -> Future<[Self.Iterator.Element.Success]> {
    return _asyncFlatMap(executor: .immediate) { $0 as! Future<Self.Iterator.Element.Success> }
  }
}
