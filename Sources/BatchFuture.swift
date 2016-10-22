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

/// Single failure fails them all
public extension Collection where Self.IndexDistance == Int, Self.Iterator.Element : Finite {
  fileprivate typealias FinalValue = Self.Iterator.Element.FinalValue

  /// joins an array of futures to a future array
  func joined() -> Future<[FinalValue]> {
    return self.asyncMap(executor: .immediate) { $0 as! Future<FinalValue> }
  }

  ///
  func reduce<Result>(executor: Executor = .primary, initialResult: Result, nextPartialResult: @escaping (Result, FinalValue) throws -> Result) -> Future<Result> {
    return self.joined().map(executor: executor) {
      try $0.reduce(initialResult, nextPartialResult)
    }
  }

}

public extension Collection where Self.IndexDistance == Int {
  /// transforms each element of collection on executor and provides future array of transformed values
  public func asyncMap<T>(executor: Executor = .primary,
                       transform: @escaping (Self.Iterator.Element) throws -> T) -> Future<[T]> {
    return self.asyncMap(executor: executor) { future(success: try transform($0)) }
  }

  /// transforms each element of collection to fallible future values on executor and provides future array of transformed values
  public func asyncMap<T>(executor: Executor = .primary,
                       transform: @escaping (Self.Iterator.Element) throws -> Future<T>) -> Future<[T]> {
    let promise = Promise<[T]>()
    var locking = makeLocking()

    var canContinue = true
    let count = self.count
    var subvalues = [T?](repeating: nil, count: count)
    var unknownSubvaluesCount = count

    for (index, value) in self.enumerated() {
      executor.execute { [weak promise] in
        guard let promise = promise else { return }
        guard canContinue else { return }

        let futureSubvalue: Future<T>
        do { futureSubvalue = try transform(value) }
        catch { futureSubvalue = future(failure: error) }

        let handler = futureSubvalue.makeFinalHandler(executor: .immediate) { [weak promise] subvalue in
          guard let promise = promise else { return }

          locking.lock()
          defer { locking.unlock() }

          guard canContinue else { return }
          subvalue.onSuccess {
            subvalues[index] = $0
            unknownSubvaluesCount -= 1
            if 0 == unknownSubvaluesCount {
              promise.succeed(with: subvalues.flatMap { $0 })
              canContinue = false
            }
          }

          subvalue.onFailure {
            promise.fail(with: $0)
            canContinue = false
          }
        }

        if let handler = handler {
          promise.insertToReleasePool(handler)
        }
      }
    }

    promise.insertToReleasePool(self)

    return promise
  }

  public func asyncMap<T, U: ExecutionContext>(context: U, executor: Executor? = nil,
                       transform: @escaping (U, Self.Iterator.Element) throws -> T) -> Future<[T]> {
    return self.asyncMap(executor: executor ?? context.executor) { [weak context] (value) -> T in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, value)
    }
  }
  
  public func asyncMap<T, U: ExecutionContext>(context: U, executor: Executor? = nil,
                       transform: @escaping (U, Self.Iterator.Element) throws -> Future<T>) -> Future<[T]> {
    return self.asyncMap(executor: executor ?? context.executor) { [weak context] (value) -> Future<T> in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try transform(context, value)
    }
  }
}
