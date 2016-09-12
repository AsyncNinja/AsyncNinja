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

public protocol _Channel {
  associatedtype Handler : _ChannelHandler
  typealias Value = Self.Handler.Value

  /// **internal use only**
  func add(handler: Handler)
}

/// **internal use only**
public protocol _ChannelHandler : class {
  associatedtype Value
  init(executor: Executor, block: @escaping (Value) -> Void)
}

public extension _Channel {
  func _onValue(executor: Executor = .primary, block: @escaping (Value) -> Void) -> Handler {
    let handler = Handler(executor: executor, block: block)
    self.add(handler: handler)
    return handler
  }

  func wait() -> Value {
    return self.wait(waitingBlock: { $0.wait(); return .success })!
  }

  func wait(timeout: DispatchTime) -> Value? {
    return self.wait(waitingBlock: { $0.wait(timeout: timeout) })
  }

  func wait(wallTimeout: DispatchWallTime) -> Value? {
    return self.wait(waitingBlock: { $0.wait(wallTimeout: wallTimeout) })
  }

  internal func wait(waitingBlock: (DispatchSemaphore) -> DispatchTimeoutResult) -> Value? {
    let sema = DispatchSemaphore(value: 0)
    var result: Value? = nil

    var handler: Handler? = self._onValue(executor: .immediate) {
      result = $0
      sema.signal()
    }
    defer { handler = nil }

    switch waitingBlock(sema) {
    case .success:
      return result
    case .timedOut:
      return nil
    }
  }

  internal func makeDerivedChannel<T>(executor: Executor, onValue: @escaping (Producer<T>, Value) -> ()) -> Channel<T> {
    let derivedChannel = Producer<T>()

    let handler = self._onValue(executor: executor) { [weak derivedChannel] in
      guard let derivedChannel = derivedChannel else { return }
      onValue(derivedChannel, $0)
    }

    derivedChannel.releasePool.insert(handler)
    return derivedChannel
  }

  func map<T>(executor: Executor = .primary, _ transform: @escaping (Value) -> T) -> Channel<T> {
    return self.makeDerivedChannel(executor: executor) { (producer, value) in
      producer.send(transform(value))
    }
  }

  func flatMap<T>(executor: Executor = .primary, transform: @escaping (Value) -> T?) -> Channel<T> {
    return self.makeDerivedChannel(executor: executor) { (producer, value) in
      if let transformedValue = transform(value) {
        producer.send(transformedValue)
      }
    }
  }

  func flatMap<S: Sequence>(executor: Executor = .primary, transform: @escaping (Value) -> S) -> Channel<S.Iterator.Element> {
    return self.makeDerivedChannel(executor: executor) { (producer, value) in
      producer.send(transform(value))
    }
  }

  func filter(executor: Executor = .primary, _ predicate: @escaping (Value) -> Bool) -> Channel<Value> {
    return self.makeDerivedChannel(executor: executor) { (producer, value) in
      if predicate(value) {
        producer.send(value)
      }
    }
  }

  func changes() -> Channel<(Value?, Value)> {
    var previousValue: Value? = nil

    return self.makeDerivedChannel(executor: .immediate) { (producer, value) in
      let change = (previousValue, value)
      previousValue = value
      producer.send(change)
    }
  }

  func enumerated() -> Channel<(Int, Value)> {
    var index: Int64 = -1
    return self.map(executor: .immediate) {
      let localIndex = Int(OSAtomicIncrement64(&index))
      return (localIndex, $0)
    }
  }
}


public extension _Channel {
    final func map<U: ExecutionContext, V>(context: U, executor: Executor? = nil, _ transform: @escaping (U, Value) -> V) -> Channel<V> {
        let derivedChannel = Producer<V>()

        let handler = self._onValue(executor: executor ?? context.executor) { [weak derivedChannel, weak context] in
            guard let derivedChannel = derivedChannel, let context = context else { return }
            derivedChannel.send(transform(context, $0))
        }

        derivedChannel.releasePool.insert(handler)
        return derivedChannel
    }

    final func onValue<U: ExecutionContext>(context: U, executor: Executor? = nil, block: @escaping (U, Value) -> Void) {
        let handler = self._onValue(executor: executor ?? context.executor) { [weak context] (value) in
            guard let context = context
                else { return }
            block(context, value)
        }
        
        context.releaseOnDeinit(handler)
    }
}
