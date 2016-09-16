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

public extension Collection where Self.IndexDistance == Int, Self.Iterator.Element : Finite {
  fileprivate typealias FinalValue = Self.Iterator.Element.FinalValue

  /// joins an array of futures to a future array
  func joined() -> Future<[FinalValue]> {
    return self.asyncMap(executor: .immediate) { $0 as! Future<FinalValue> }
  }

  /// reduces results of futures
  func reduce<Result>(executor: Executor = .primary, initialResult: Result,
              nextPartialResult: @escaping (Result, FinalValue) -> Result) -> Future<Result> {
    return self.joined().mapFinal(executor: executor) {
      $0.reduce(initialResult, nextPartialResult)
    }
  }

  func reduce<Result>(executor: Executor = .primary, initialResult: Result,
              nextPartialResult: @escaping (Result, FinalValue) throws -> Result) -> FallibleFuture<Result> {
    return self.joined().mapFinal(executor: executor) { final in
      fallible { try final.reduce(initialResult, nextPartialResult) }
    }
  }
}

public extension Collection where Self.IndexDistance == Int {
  /// transforms each element of collection on executor and provides future array of transformed values
  func asyncMap<T>(executor: Executor = .primary,
                transform: @escaping (Self.Iterator.Element) -> T) -> Future<[T]> {
    return self.asyncMap(executor: executor) { future(value: transform($0)) }
  }

  /// transforms each element of collection to future value on executor and provides future array of transformed values
  func asyncMap<T>(executor: Executor = .primary,
                transform: @escaping (Self.Iterator.Element) -> Future<T>) -> Future<[T]> {
    let promise = Promise<[T]>()
    let sema = DispatchSemaphore(value: 1)

    let count = self.count
    var subvalues = [T?](repeating: nil, count: count)
    var unknownSubvaluesCount = count

    for (index, value) in self.enumerated() {
      executor.execute {
        weak var weakPromise = promise
        let handler = transform(value).makeFinalHandler(executor: .immediate) {
          guard let promise = weakPromise else { return }
          sema.wait()
          defer { sema.signal() }

          subvalues[index] = $0
          unknownSubvaluesCount -= 1
          if 0 == unknownSubvaluesCount {
            promise.complete(with: subvalues.flatMap { $0 })
          }
        }

        promise.releasePool.insert(handler)
      }
    }
    
    return promise
  }
}
