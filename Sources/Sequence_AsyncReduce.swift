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
    ) -> Future<T> {
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
    // swiftlint:disable:next line_length
    _ nextPartialResult: @escaping (_ strongContext: C, _ accumulator: T, _ element: Self.Iterator.Element.Success) throws -> T
    ) -> Future<T> {
    let future = asyncReduce(initialResult,
                              executor: executor ?? context.executor
    ) { [weak context] (accumulator, value) -> T in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try nextPartialResult(context, accumulator, value)
    }

    if let promise = future as? Promise<T> {
      context.addDependent(completable: promise)
    }

    return future
  }

  /// **internal use only**
  internal func _asyncReduce<T>(
    _ initialResult: T,
    executor: Executor = .primary,
    _ nextPartialResult: @escaping (_ accumulator: T, _ element: Self.Iterator.Element.Success) throws -> T
    ) -> Future<T> {
    // Test: BatchFutureTests.testReduce
    // Test: BatchFutureTests.testReduceThrows

    let values: [Self.Iterator.Element.Success?] = self.map { _ in nil }
    guard !values.isEmpty else { return .just(initialResult) }
    let promise = Promise<T>()
    let helper = SequenceAsyncReduceHelper(
      destination: promise,
      values: values,
      initialResult: initialResult,
      executor: executor,
      nextPartialResult: nextPartialResult)

    for (index, future) in enumerated() {
      promise._asyncNinja_retainHandlerUntilFinalization(helper.makeHandler(index: index, future: future))
    }

    return promise
  }
}

private class SequenceAsyncReduceHelper<InputElement, OutputElement, Destination: Completable>
where Destination.Success == OutputElement {
  let initialResult: OutputElement
  let executor: Executor
  let nextPartialResult: (_ accumulator: OutputElement, _ element: InputElement) throws -> OutputElement
  var locking = makeLocking(isFair: true)
  var canContinue = true
  var unknownSubvaluesCount: Int
  var values: [InputElement?]
  weak var destination: Destination?

  init(
    destination: Destination,
    values: [InputElement?],
    initialResult: OutputElement,
    executor: Executor,
    nextPartialResult: @escaping (_ accumulator: OutputElement, _ element: InputElement) throws -> OutputElement
    ) {
    self.destination = destination
    self.values = values
    self.unknownSubvaluesCount = values.count
    self.initialResult = initialResult
    self.executor = executor
    self.nextPartialResult = nextPartialResult
  }

  func updateAndTest(index: Int, subcompletion: Fallible<InputElement>) -> Fallible<[InputElement?]>? {
    switch subcompletion {
    case let .success(success):
      values[index] = success
      unknownSubvaluesCount -= 1
      if 0 == unknownSubvaluesCount {
        return .just(values)
      } else {
        return nil
      }
    case let .failure(failure):
      canContinue = false
      return .failure(failure)
    }
  }

  func makeHandler<T: Completing>(index: Int, future: T) -> AnyObject? where T.Success == InputElement {
    return future.makeCompletionHandler(executor: .immediate) { (completion, originalExecutor) in
      guard
        self.canContinue,
        case .some = self.destination,
        let valuesToReduce = self.locking.locker(index, completion, self.updateAndTest)
        else { return }

      switch valuesToReduce {
      case let .success(success):
        self.executor.execute(from: originalExecutor) { _ in
          do {
            func _nextPartialResult(_ accumulator: OutputElement, _ element: InputElement?) throws -> OutputElement {
              return try self.nextPartialResult(accumulator, element!)
            }

            let result = try success.reduce(self.initialResult, _nextPartialResult)
            self.destination?.succeed(result)
          } catch {
            self.destination?.fail(error)
          }
        }
      case let .failure(failure):
        self.destination?.fail(failure)
      }
    }
  }
}
