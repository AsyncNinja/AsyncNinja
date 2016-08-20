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
  typealias Handler = StreamHandler<T>

  init() { }

  final public func onValue(executor: Executor = .primary, block: @escaping (Value) -> Void) {
    let handler = Handler(executor: executor, block: block)
    self.add(handler: handler)
  }

  public func map<T>(executor: Executor = .primary, _ transform: @escaping  (Value) -> T) -> Stream<T> {
    let mutableStream = Producer<T>()
    self.onValue(executor: executor) { value in
      mutableStream.send(transform(value))
    }
    return mutableStream
  }

  func add(handler: Handler) {
    fatalError() // abstract
  }

  public func changes() -> Stream<(T?, T)> {
    let mutableStream = Producer<(T?, T)>()
    var previousValue: Value? = nil
    self.onValue(executor: .immediate) {
      let change = (previousValue, $0)
      mutableStream.send(change)
      previousValue = $0
    }
    return mutableStream
  }

  public func bufferedPairs() -> Stream<(T, T)> {
    return self.buffered(capacity: 2).map(executor: .immediate) { ($0[0], $0[1]) }
  }

  public func buffered(capacity: Int) -> Stream<[T]> {
    let bufferingStream = Producer<[T]>()
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

  public func enumerated() -> Stream<(Int, T)> {
    var index = -1
    return self.map(executor: .immediate) {
      index += 1
      return (index, $0)
    }
  }
}

struct StreamHandler<T> {
  var executor: Executor
  var block: (T) -> Void

  func handle(value: T) {
    self.executor.execute { self.block(value) }
  }
}
