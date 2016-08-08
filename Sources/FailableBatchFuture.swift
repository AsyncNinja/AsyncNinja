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

  private init<S : Collection where S.Iterator.Element : Future<Failable<T>>, S.IndexDistance == Int>(futures: S) {
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
