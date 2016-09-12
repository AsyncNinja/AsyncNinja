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

public class Channel<T> {
  public typealias Value = T
  public typealias Handler = ChannelHandler<Value>

  let releasePool = ReleasePool()

  init() { }

  /// **internal use only**
  public func add(handler: Handler) {
    fatalError() // abstract
  }
}

extension Channel : _Channel {
}

public extension Channel {
  func bufferedPairs() -> Channel<(T, T)> {
    return self.buffered(capacity: 2).map(executor: .immediate) { ($0[0], $0[1]) }
  }

  func buffered(capacity: Int) -> Channel<[T]> {
    var buffer = [T]()
    buffer.reserveCapacity(capacity)

    return self.makeDerivedChannel(executor: .immediate) { (producer, value) in
      buffer.append(value)
      if capacity == buffer.count {
        producer.send(buffer)
        buffer.removeAll(keepingCapacity: true)
      }
    }
  }

  func enumerated() -> Channel<(Int, T)> {
    var index: Int64 = -1
    return self.map(executor: .immediate) {
      let localIndex = Int(OSAtomicIncrement64(&index))
      return (localIndex, $0)
    }
  }
}

/// **internal use only**
final public class ChannelHandler<T> : _ChannelHandler {
  public typealias Value = T

  let executor: Executor
  let block: (Value) -> Void

  public init(executor: Executor, block: @escaping (Value) -> Void) {
    self.executor = executor
    self.block = block
  }

  func handle(value: Value) {
    let block = self.block
    self.executor.execute { block(value) }
  }
}
