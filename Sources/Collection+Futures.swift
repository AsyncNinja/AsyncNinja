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

/// Collection improved with AsyncNinja
/// Single failure fails them all
public extension Sequence where Self.Iterator.Element: Completing {

  /// reduces results of collection of futures to future accumulated value
  func asyncReduce<Result>(
    _ initialResult: Result,
    executor: Executor = .primary,
    _ nextPartialResult: @escaping (Result, Self.Iterator.Element.Success) throws -> Result)
    -> Future<Result> {

      // Test: BatchFutureTests.testReduce
      // Test: BatchFutureTests.testReduceThrows
      
      let promise = Promise<Result>()
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

public extension Collection where Self.IndexDistance == Int, Self.Iterator.Element: Completing {

  /// joins an array of futures to a future array
  func joined() -> Future<[Self.Iterator.Element.Success]> {
    return _asyncFlatMap(executor: .immediate) { $0 as! Future<Self.Iterator.Element.Success> }
  }
}

/// Collection improved with AsyncNinja
public extension Collection where Self.IndexDistance == Int {
  
  /// **internal use only**
  func _asyncMap<T>(
    executor: Executor = .primary,
    _ transform: @escaping (Self.Iterator.Element) throws -> T) -> Promise<[T]> {
    let count = self.count
    let promise = Promise<[T]>()
    guard count > 0 else {
      promise.succeed([])
      return promise
    }
    var locking = makeLocking()
    var canContinue = true
    var subvalues = [T?](repeating: nil, count: count)
    var unknownSubvaluesCount = count
    
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
  
  /// **internal use only**
  func _asyncFlatMap<T>(
    executor: Executor,
    _ transform: @escaping (Self.Iterator.Element) throws -> Future<T>) -> Promise<[T]> {
    let promise = Promise<[T]>()
    let count = self.count
    guard count > 0 else {
      promise.succeed([])
      return promise
    }
    
    var locking = makeLocking()
    var canContinue = true
    var subvalues = [T?](repeating: nil, count: count)
    var unknownSubvaluesCount = count
    
    for (index, value) in self.enumerated() {
      executor.execute(from: nil) {
        [weak promise] (originalExecutor) in
        guard let promise = promise, canContinue else { return }
        
        let futureSubvalue: Future<T>
        do { futureSubvalue = try transform(value) }
        catch { futureSubvalue = .failed(error) }
        
        let handler = futureSubvalue.makeCompletionHandler(executor: .immediate)
        {
          [weak promise] (subvalue, originalExecutor) in
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
      }
    }

    promise._asyncNinja_notifyFinalization {
      canContinue = false
    }
    
    return promise
  }
  
  /// transforms each element of collection on executor and provides future array of transformed values
  public func asyncMap<T>(
    executor: Executor = .primary,
    _ transform: @escaping (Self.Iterator.Element) throws -> T) -> Future<[T]> {
    return _asyncMap(executor: executor, transform)
  }
  
  /// transforms each element of collection to fallible future values on executor and provides future array of transformed values
  public func asyncFlatMap<T>(
    executor: Executor = .primary,
    _ transform: @escaping (Self.Iterator.Element) throws -> Future<T>) -> Future<[T]> {
    return _asyncFlatMap(executor: executor, transform)
  }
  
  /// transforms each element of collection to fallible future values on executor and provides future array of transformed values
  public func asyncMap<T, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (C, Self.Iterator.Element) throws -> T) -> Future<[T]> {
    let promise = _asyncMap(executor: executor ?? context.executor) {
      [weak context] (value) -> T in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, value)
    }
    
    context.addDependent(completable: promise)
    return promise
  }
  
  /// transforms each element of collection to fallible future values on executor and provides future array of transformed values
  public func asyncFlatMap<T, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ transform: @escaping (C, Self.Iterator.Element) throws -> Future<T>
    ) -> Future<[T]> {
    let executor_ = executor ?? context.executor
    let promise = _asyncFlatMap(executor: executor_) {
      [weak context] (value) -> Future<T> in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, value)
    }
    
    context.addDependent(completable: promise)
    
    return promise
  }
}
