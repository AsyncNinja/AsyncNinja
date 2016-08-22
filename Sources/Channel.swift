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

public class Channel<T> : Consumable {
  public typealias Value = T
  typealias Handler = ChannelHandler<T>

  init() { }

  final public func onValue(executor: Executor = .primary, block: @escaping (Value) -> Void) {
    let handler = Handler(executor: executor, block: block)
    self.add(handler: handler)
  }

  public func map<T>(executor: Executor = .primary, _ transform: @escaping  (Value) -> T) -> Channel<T> {
    let mutableChannel = Producer<T>()
    self.onValue(executor: executor) { value in
      mutableChannel.send(transform(value))
    }
    return mutableChannel
  }

  func add(handler: Handler) {
    fatalError() // abstract
  }

  public func changes() -> Channel<(T?, T)> {
    let mutableChannel = Producer<(T?, T)>()
    var previousValue: Value? = nil
    self.onValue(executor: .immediate) {
      let change = (previousValue, $0)
      mutableChannel.send(change)
      previousValue = $0
    }
    return mutableChannel
  }

  public func bufferedPairs() -> Channel<(T, T)> {
    return self.buffered(capacity: 2).map(executor: .immediate) { ($0[0], $0[1]) }
  }

  public func buffered(capacity: Int) -> Channel<[T]> {
    let bufferingChannel = Producer<[T]>()
    var buffer = [T]()
    buffer.reserveCapacity(capacity)

    self.onValue(executor: .immediate) {
      buffer.append($0)
      if capacity == buffer.count {
        bufferingChannel.send(buffer)
        buffer.removeAll(keepingCapacity: true)
      }
    }

    return bufferingChannel
  }

  public func enumerated() -> Channel<(Int, T)> {
    var index = -1
    return self.map(executor: .immediate) {
      index += 1
      return (index, $0)
    }
  }
}

struct ChannelHandler<T> {
  var executor: Executor
  var block: (T) -> Void

  func handle(value: T) {
    self.executor.execute { self.block(value) }
  }
}
