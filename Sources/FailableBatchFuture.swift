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

class FailableBatchFuture<T> : MutableFuture<Failable<[T]>> {
  let count: Int
  private var _subsuccesses: [T?]
  private var _unknownSubvaluesCount: Int

  init<S : Collection>(futures: S) where S.Iterator.Element : Future<Failable<T>>, S.IndexDistance == Int {
    self.count = futures.count
    _unknownSubvaluesCount = self.count
    _subsuccesses = Array<T?>(repeating: nil, count: self.count)
    super.init()


    for (index, future) in futures.enumerated() {
      future.onValue(executor: Executor.immediate) { [weak self] in
        self?.complete(subvalue: $0, index: index)
      }
    }
  }

  @discardableResult
  func complete(subvalue: Failable<T>, index: Int) {
    self.tryUpdateAndMakeValue {
      guard nil == _subsuccesses[index] else { return nil }

      switch subvalue {
      case let .success(succesValue):
        _subsuccesses[index] = succesValue
        _unknownSubvaluesCount -= 1
        return _unknownSubvaluesCount == 0 ? Failable(success: _subsuccesses.flatMap { $0 }) : nil
      case let .failure(failureValue):
        return .failure(failureValue)
      }
    }
  }
}

/// Single failure fails them all
public func combine<T, S : Collection>(futures: [Future<Failable<T>>]) -> Future<Failable<[T]>>
  where S.Iterator.Element : Future<Failable<T>>, S.IndexDistance == Int {
    return FailableBatchFuture(futures: futures)
}

public extension Collection where Self.IndexDistance == Int {
  public func map<T>(executor: Executor, transform: @escaping (Self.Iterator.Element) throws -> T) -> Future<Failable<[T]>> {
    let promise = Promise<Failable<[T]>>()
    let sema = DispatchSemaphore(value: 1)

    var canContinue = true
    let count = self.count
    var subvalues = [T?](repeating: nil, count: count)
    var unknownSubvaluesCount = count

    for (index, value) in self.enumerated() {
      executor.execute {
        guard canContinue else { return }

        let subvalue = failable { try transform(value) }

        sema.wait()
        defer { sema.signal() }

        guard canContinue else { return }
        subvalue.onSuccess {
          subvalues[index] = $0
          unknownSubvaluesCount -= 1
          if 0 == unknownSubvaluesCount {
            promise.complete(with: Failable(success: subvalues.flatMap { $0 }))
            canContinue = false
          }
        }

        subvalue.onFailure {
          promise.complete(with: Failable(failure: $0))
          canContinue = false
        }
      }
    }

    return promise
  }
}
