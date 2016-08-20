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

/// Single failure fails them all
public extension Collection where Self.IndexDistance == Int, Self.Iterator.Element : _Future, Self.Iterator.Element.Value : _Fallible {
  fileprivate typealias Value = Self.Iterator.Element.Value.Success

  /// joins an array of futures to a future array
  func joined() -> FallibleFuture<[Value]> {
    return self.map(executor: .immediate) { $0 as! FallibleFuture<Value> }
  }

  ///
  func reduce<Result>(executor: Executor = .primary, initialResult: Result, nextPartialResult: @escaping (Result, Value) throws -> Result) -> FallibleFuture<Result> {
    return self.joined().map(executor: executor) {
      $0.liftSuccess { try $0.reduce(initialResult, nextPartialResult) }
    }
  }

}

public extension Collection where Self.IndexDistance == Int {
  /// transforms each element of collection on executor and provides future array of transformed values
  public func map<T>(executor: Executor, transform: @escaping (Self.Iterator.Element) throws -> T) -> FallibleFuture<[T]> {
    return self.map(executor: executor) { future(success: try transform($0)) }
  }

  /// transforms each element of collection to future values on executor and provides future array of transformed values
  public func map<T>(executor: Executor, transform: @escaping (Self.Iterator.Element) throws -> Future<T>) -> FallibleFuture<[T]> {
    return self.map(executor: executor) { (try transform($0)).map(executor: .immediate) { $0 } }
  }

  /// transforms each element of collection to fallible future values on executor and provides future array of transformed values
  public func map<T>(executor: Executor, transform: @escaping (Self.Iterator.Element) throws -> FallibleFuture<T>) -> FallibleFuture<[T]> {
    let promise = Promise<Fallible<[T]>>()
    let sema = DispatchSemaphore(value: 1)

    var canContinue = true
    let count = self.count
    var subvalues = [T?](repeating: nil, count: count)
    var unknownSubvaluesCount = count

    for (index, value) in self.enumerated() {
      executor.execute {

        sema.wait()
        let canContinue_ = canContinue
        sema.signal()

        guard canContinue_ else { return }

        let futureSubvalue: FallibleFuture<T>
        do { futureSubvalue = try transform(value) }
        catch { futureSubvalue = future(failure: error) }

        futureSubvalue.onValue { subvalue in
          sema.wait()
          defer { sema.signal() }

          guard canContinue else { return }
          subvalue.onSuccess {
            subvalues[index] = $0
            unknownSubvaluesCount -= 1
            if 0 == unknownSubvaluesCount {
              promise.complete(with: Fallible(success: subvalues.flatMap { $0 }))
              canContinue = false
            }
          }

          subvalue.onFailure {
            promise.complete(with: Fallible(failure: $0))
            canContinue = false
          }
        }
      }
    }

    return promise
  }
}
