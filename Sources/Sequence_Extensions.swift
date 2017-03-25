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
    ) -> Future<[T]>
  {
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
    ) -> Future<[T]>
  {
    let promise = _asyncMap(executor: executor ?? context.executor) {
      [weak context] (value) -> T in
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
    ) -> Promise<[T]>
  {
    var subvalues: [T?] = self.map { _ in nil }
    let promise = Promise<[T]>()
    guard !subvalues.isEmpty else {
      promise.succeed([])
      return promise
    }
    var locking = makeLocking()
    var canContinue = true
    var unknownSubvaluesCount = subvalues.count

    for (index, value) in self.enumerated() {
      executor.execute(from: nil) {
        [weak promise] (originalExecutor) in
        guard let promise = promise, canContinue else { return }

        let subvalue: T
        do { subvalue = try transform(value) }
        catch {
          promise.fail(error, from: originalExecutor)
          canContinue = false
          return
        }

        locking.lock()
        defer { locking.unlock() }
        subvalues[index] = subvalue
        unknownSubvaluesCount -= 1
        if 0 == unknownSubvaluesCount {
          promise.succeed(subvalues.map { $0! },
                          from: originalExecutor)
        }
      }
    }

    promise._asyncNinja_notifyFinalization {
      canContinue = false
    }

    return promise
  }
}

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
    ) -> Future<[T.Success]>
  {
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
    ) -> Future<[T.Success]>
  {
    let executor_ = executor ?? context.executor
    let promise = _asyncFlatMap(executor: executor_) {
      [weak context] (value) -> T in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, value)
    }

    context.addDependent(completable: promise)
    return promise
  }

  /// **internal use only**
  internal func _asyncFlatMap<T: Completing>(
    executor: Executor,
    _ transform: @escaping (_ element: Self.Iterator.Element) throws -> T
    ) -> Promise<[T.Success]>
  {
    let promise = Promise<[T.Success]>()
    var subvalues: [T.Success?] = self.map { _ in nil }

    guard !subvalues.isEmpty else {
      promise.succeed([])
      return promise
    }

    var locking = makeLocking()
    var canContinue = true
    var unknownSubvaluesCount = subvalues.count

    for (index, value) in self.enumerated() {
      executor.execute(from: nil) {
        [weak promise] (originalExecutor) in
        guard let promise = promise, canContinue else { return }

        do {
          let futureSubvalue: T = try transform(value)
          let handler = futureSubvalue.makeCompletionHandler(executor: .immediate)
          { [weak promise] (subvalue, originalExecutor) in
            guard let promise = promise else { return }

            locking.lock()
            defer { locking.unlock() }

            guard canContinue else { return }
            subvalue.onSuccess {
              subvalues[index] = $0
              unknownSubvaluesCount -= 1
              assert(unknownSubvaluesCount >= 0)
              if 0 == unknownSubvaluesCount {
                promise.succeed(subvalues.map { $0! },
                                from: originalExecutor)
              }
            }

            subvalue.onFailure {
              promise.fail($0, from: originalExecutor)
              canContinue = false
            }
          }
          
          promise._asyncNinja_retainHandlerUntilFinalization(handler)
        } catch {
          promise.fail(error, from: originalExecutor)
          canContinue = false
        }
      }
    }

    promise._asyncNinja_notifyFinalization {
      canContinue = false
    }
    
    return promise
  }
}

// MARK: - asyncReduce

public extension Sequence where Self.Iterator.Element: Completing {

  /// Asyncronously reduces over each element of the Sequence of Completing
  ///
  /// - Parameters:
  ///   - executor: to perform transform on
  ///   - nextPartialResult: function to reduce with
  ///   - element: to transform
  /// - Returns: a Future of Array of results
  func asyncReduce<T>(
    _ initialResult: T,
    executor: Executor = .primary,
    _ nextPartialResult: @escaping (_ accumulator: T, _ element: Self.Iterator.Element.Success) throws -> T
    ) -> Promise<T>
  {
    // Test: BatchFutureTests.testReduce
    // Test: BatchFutureTests.testReduceThrows
    return _asyncReduce(initialResult, executor: executor, nextPartialResult)
  }

  /// Asyncronously reduces over each element of the Sequence of Completing
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - nextPartialResult: function to reduce with
  ///   - element: to transform
  /// - Returns: a Future of Array of results
  func asyncReduce<T, C: ExecutionContext>(
    _ initialResult: T,
    context: C,
    executor: Executor? = nil,
    _ nextPartialResult: @escaping (_ strongContext: C, _ accumulator: T, _ element: Self.Iterator.Element.Success) throws -> T
    ) -> Future<T>
  {
    let promise = asyncReduce(initialResult, executor: executor ?? context.executor) {
      [weak context] (accumulator, value) -> T in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try nextPartialResult(context, accumulator, value)
    }

    context.addDependent(completable: promise)
    return promise
  }

  /// **internal use only**
  internal func _asyncReduce<T>(
    _ initialResult: T,
    executor: Executor = .primary,
    _ nextPartialResult: @escaping (_ accumulator: T, _ element: Self.Iterator.Element.Success) throws -> T
    ) -> Promise<T>
  {
    // Test: BatchFutureTests.testReduce
    // Test: BatchFutureTests.testReduceThrows

    let promise = Promise<T>()
    var values: Array<Self.Iterator.Element.Success?> = self.map { _ in nil }
    var unknownSubvaluesCount = values.count
    guard unknownSubvaluesCount > 0 else {
      promise.succeed(initialResult)
      return promise
    }

    var locking = makeLocking(isFair: true)
    var canContinue = true

    for (index, future) in self.enumerated() {
      let handler = future.makeCompletionHandler(executor: .immediate)
      {
        [weak promise] (completion, originalExecutor) -> Void in
        locking.lock()
        guard
          canContinue,
          case .some = promise
          else {
            locking.unlock()
            return
        }
        switch completion {
        case let .success(success):
          values[index] = success
          unknownSubvaluesCount -= 1
          let runReduce = 0 == unknownSubvaluesCount
          locking.unlock()

          if runReduce {
            executor.execute(from: originalExecutor) { [weak promise] (originalExecutor) in
              locking.lock()
              defer { locking.unlock() }
              do {
                let result = try values.reduce(initialResult) { (accumulator, value) in
                  return try nextPartialResult(accumulator, value!)
                }
                promise?.succeed(result)
              } catch {
                promise?.fail(error)
              }
            }
          }
        case let .failure(failure):
          canContinue = false
          locking.unlock()

          promise?.fail(failure)

        }
      }

      promise._asyncNinja_retainHandlerUntilFinalization(handler)
    }
    
    return promise
  }
}

// MARK: -

public extension Sequence where Self.Iterator.Element: Completing {

  /// joins a Sequence of Completing to a Future of Array
  func joined() -> Future<[Self.Iterator.Element.Success]> {
    return _asyncFlatMap(executor: .immediate) { $0 as! Future<Self.Iterator.Element.Success> }
  }
}
