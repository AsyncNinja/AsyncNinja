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

  func add(handler: Handler) {
    fatalError() // abstract
  }

  func remove(handler: Handler) {
    fatalError() // abstract
  }

  final public func onValue(executor: Executor = .primary, block: @escaping (Value) -> Void) {
    let handler = Handler(executor: executor, block: block)
    self.add(handler: handler)
  }

  final public func wait(waitingBlock: (DispatchSemaphore) -> DispatchTimeoutResult) -> T? {
    let sema = DispatchSemaphore(value: 0)
    var result: Value? = nil

    let handler = Handler(executor: .immediate) {
      result = $0
      sema.signal()
    }
    self.add(handler: handler)
    defer { self.remove(handler: handler) }

    switch waitingBlock(sema) {
    case .success:
      return result
    case .timedOut:
      return nil
    }
  }

  public func map<T>(executor: Executor = .primary, _ transform: @escaping  (Value) -> T) -> Channel<T> {
    return makeDerivedChannel { (producer, value) in
      executor.execute { producer.send(transform(value)) }
    }
  }

  public func changes() -> Channel<(T?, T)> {
    var previousValue: Value? = nil

    return makeDerivedChannel { (producer, value) in
      let change = (previousValue, value)
      producer.send(change)
      previousValue = value
    }
  }

  public func bufferedPairs() -> Channel<(T, T)> {
    return self.buffered(capacity: 2).map(executor: .immediate) { ($0[0], $0[1]) }
  }

  func makeDerivedChannel<T>(onValue: @escaping (Producer<T>, Value) -> ()) -> Channel<T> {
    let derivedChannel = Producer<T>()
    weak var weakDerivedChannel: Producer<T>? = derivedChannel
    weak var weakHandler: Handler? = nil

    let handler = Handler(executor: .immediate) { [weak self] in
      guard let derivedChannel = weakDerivedChannel else {
        if let self_ = self, let handler = weakHandler {
          self_.remove(handler: handler)
        }
        return
      }

      onValue(derivedChannel, $0)
    }
    weakHandler = handler
    self.add(handler: handler)
    return derivedChannel
  }

  public func buffered(capacity: Int) -> Channel<[T]> {
    var buffer = [T]()
    buffer.reserveCapacity(capacity)

    return makeDerivedChannel { (producer, value) in
      buffer.append(value)
      if capacity == buffer.count {
        producer.send(buffer)
        buffer.removeAll(keepingCapacity: true)
      }
    }
  }

  public func enumerated() -> Channel<(Int, T)> {
    var index = -1
    return self.map(executor: .immediate) {
      index += 1
      return (index, $0)
    }
  }
}

final class ChannelHandler<T> : Hashable {
  let executor: Executor
  let block: (T) -> Void
  var hashValue: Int { return ObjectIdentifier(self).hashValue }

  static func ==(lhs: ChannelHandler<T>, rhs: ChannelHandler<T>) -> Bool {
    return lhs === rhs
  }

  init(executor: Executor, block: @escaping (T) -> Void) {
    self.executor = executor
    self.block = block
  }

  func handle(value: T) {
    let block = self.block
    self.executor.execute { block(value) }
  }
}
