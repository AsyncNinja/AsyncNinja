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

class BatchFuture<T> : MutableFuture<[T]> {
  let count: Int
  private var _subvalues: [T?]
  private var _unknownSubvaluesCount: Int

  init<S : Collection>(futures: S)
    where S.Iterator.Element : Future<T>, S.IndexDistance == Int {
    self.count = futures.count
    _unknownSubvaluesCount = self.count
    _subvalues = Array<T?>(repeating: nil, count: self.count)
    super.init()


    for (index, future) in futures.enumerated() {
      future.onValue(executor: .immediate) { [weak self] in
        self?.complete(subvalue: $0, index: index)
      }
    }
  }

  func complete(subvalue: T, index: Int) {
    self.tryUpdateAndMakeValue {
      guard nil == _subvalues[index] else { return nil }
      _subvalues[index] = subvalue
      _unknownSubvaluesCount -= 1
      return _unknownSubvaluesCount == 0 ? _subvalues.flatMap { $0 } : nil
    }
  }
}

public func combine<T, S : Collection>(futures: S) -> Future<[T]>
  where S.Iterator.Element : Future<T>, S.IndexDistance == Int {
    return BatchFuture(futures: futures)
}

public extension Collection where Self.IndexDistance == Int {
  public func map<T>(executor: Executor = .primary, transform: @escaping (Self.Iterator.Element) -> T) -> Future<[T]> {
    let promise = Promise<[T]>()
    let sema = DispatchSemaphore(value: 1)

    let count = self.count
    var subvalues = [T?](repeating: nil, count: count)
    var unknownSubvaluesCount = count

    for (index, value) in self.enumerated() {
      executor.execute {
        let subvalue = transform(value)

        sema.wait()
        defer { sema.signal() }

        subvalues[index] = subvalue
        unknownSubvaluesCount -= 1
        if 0 == unknownSubvaluesCount {
          promise.complete(with: subvalues.flatMap { $0 })
        }
      }
    }
    
    return promise
  }

  public func map<T>(executor: Executor = .primary, transform: @escaping (Self.Iterator.Element) -> Future<T>) -> Future<[T]> {
    let promise = Promise<[T]>()
    let sema = DispatchSemaphore(value: 1)

    let count = self.count
    var subvalues = [T?](repeating: nil, count: count)
    var unknownSubvaluesCount = count

    for (index, value) in self.enumerated() {
      executor.execute {
        let futureSubvalue = transform(value)
        futureSubvalue.onValue { subvalue in

          sema.wait()
          defer { sema.signal() }

          subvalues[index] = subvalue
          unknownSubvaluesCount -= 1
          if 0 == unknownSubvaluesCount {
            promise.complete(with: subvalues.flatMap { $0 })
          }
        }
      }
    }

    return promise
  }
}
