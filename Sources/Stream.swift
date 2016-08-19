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

public class Stream<T> : Channel {
  public typealias Value = T
  public typealias Handler = (executor: Executor, block: (Value) -> Void)

  init() { }

  public func onValue(executor: Executor, block: @escaping (Value) -> Void) {
    fatalError() // abstract
  }

  public func map<T>(executor: Executor, _ transform: @escaping  (Value) -> T) -> Stream<T> {
    let mutableStream = MutableStream<T>()
    self.onValue(executor: executor) { value in
      mutableStream.send(transform(value))
    }
    return mutableStream
  }

  public func changes() -> Stream<(T?, T)> {
    let mutableStream = MutableStream<(T?, T)>()
    var previousValue: Value? = nil
    self.onValue(executor: .immediate) {
      let change = (previousValue, $0)
      mutableStream.send(change)
      previousValue = $0
    }
    return mutableStream
  }

  public func bufferPairs() -> Stream<(T, T)> {
    return self.buffer(capacity: 2).map(executor: .immediate) { ($0[0], $0[1]) }
  }

  public func buffer(capacity: Int) -> Stream<[T]> {
    let bufferingStream = MutableStream<[T]>()
    var buffer = [T]()
    buffer.reserveCapacity(capacity)

    self.onValue(executor: .immediate) {
      buffer.append($0)
      if capacity == buffer.count {
        bufferingStream.send(buffer)
        buffer.removeAll(keepingCapacity: true)
      }
    }

    return bufferingStream
  }
}
