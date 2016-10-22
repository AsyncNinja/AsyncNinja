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

public protocol Periodic : class {
  associatedtype Value
  associatedtype PeriodicValue
  associatedtype PeriodicHandler : AnyObject

  /// **internal use only**
  func makePeriodicHandler(executor: Executor,
                             block: @escaping (PeriodicValue) -> Void) -> PeriodicHandler?
}

public extension Periodic {
  internal func makeProducer<T>(executor: Executor,
                             onPeriodic: @escaping (PeriodicValue, InfiniteProducer<T>) -> Void) -> InfiniteProducer<T> {
    let producer = InfiniteProducer<T>()
    let handler = self.makePeriodicHandler(executor: executor) { [weak producer] (periodicValue) in
      guard let producer = producer else { return }
      onPeriodic(periodicValue, producer)
    }

    if let handler = handler {
      producer.insertToReleasePool(handler)
    }
    return producer
  }

  internal func makeChannel<T>(executor: Executor,
                            onPeriodic: @escaping (PeriodicValue, (T) -> Void) -> Void) -> InfiniteChannel<T> {
    return self.makeProducer(executor: executor) { (periodicValue: PeriodicValue, producer: InfiniteProducer<T>) -> Void in
      onPeriodic(periodicValue, producer.send)
    }
  }

  func next() -> PeriodicValue {
    return self.next(waitingBlock: { $0.wait(); return .success })!
  }

  func next(timeout: DispatchTime) -> PeriodicValue? {
    return self.next(waitingBlock: { $0.wait(timeout: timeout) })
  }

  func next(wallTimeout: DispatchWallTime) -> PeriodicValue? {
    return self.next(waitingBlock: { $0.wait(wallTimeout: wallTimeout) })
  }

  internal func next(waitingBlock: (DispatchSemaphore) -> DispatchTimeoutResult) -> PeriodicValue? {
    let sema = DispatchSemaphore(value: 0)
    var result: PeriodicValue? = nil

    var handler: PeriodicHandler? = self.makePeriodicHandler(executor: .immediate) {
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

  func mapPeriodic<T>(executor: Executor = .primary,
                   transform: @escaping (PeriodicValue) -> T) -> InfiniteChannel<T> {
    return self.makeChannel(executor: executor) { (PeriodicValue, send) in
      let transformedValue = transform(PeriodicValue)
      send(transformedValue)
    }
  }

  func flatMapPeriodic<T>(executor: Executor = .primary,
                         transform: @escaping (PeriodicValue) -> T?) -> InfiniteChannel<T> {
    return self.makeChannel(executor: executor) { (PeriodicValue, send) in
      if let transformedValue = transform(PeriodicValue) {
        send(transformedValue)
      }
    }
  }

  func flatMapPeriodic<S: Sequence>(executor: Executor = .primary,
                         transform: @escaping (PeriodicValue) -> S) -> InfiniteChannel<S.Iterator.Element> {
    return self.makeChannel(executor: executor) { (PeriodicValue, send) in
      transform(PeriodicValue).forEach(send)
    }
  }

  func filterPeriodic(executor: Executor = .immediate,
                        predicate: @escaping (PeriodicValue) -> Bool) -> InfiniteChannel<PeriodicValue> {
    return self.makeChannel(executor: executor) { (PeriodicValue, send) in
      if predicate(PeriodicValue) {
        send(PeriodicValue)
      }
    }
  }

  func changes() -> InfiniteChannel<(PeriodicValue?, PeriodicValue)> {
    var previousValue: PeriodicValue? = nil

    return self.makeChannel(executor: .immediate) { (value, send) in
      let change = (previousValue, value)
      previousValue = value
      send(change)
    }
  }

  #if os(Linux)
  func enumerated() -> InfiniteChannel<(Int, PeriodicValue)> {
    let sema = DispatchSemaphore(value: 1)
    var index = 0
    return self.mapPeriodic(executor: .immediate) {
      sema.wait()
      defer { sema.signal() }
      let localIndex = index
      index += 1
      return (localIndex, $0)
    }
  }
  #else
  func enumerated() -> InfiniteChannel<(Int, PeriodicValue)> {
    var index: OSAtomic_int64_aligned64_t = -1
    return self.mapPeriodic(executor: .immediate) {
      let localIndex = Int(OSAtomicIncrement64(&index))
      return (localIndex, $0)
    }
  }
  #endif

  func bufferedPairs() -> InfiniteChannel<(PeriodicValue, PeriodicValue)> {
    return self.buffered(capacity: 2).map(executor: .immediate) { ($0[0], $0[1]) }
  }

  func buffered(capacity: Int) -> InfiniteChannel<[PeriodicValue]> {
    var buffer = [PeriodicValue]()
    buffer.reserveCapacity(capacity)
    var locking = makeLocking()

    return self.makeChannel(executor: .immediate) { (PeriodicValue, send) in
      locking.lock()
      buffer.append(PeriodicValue)
      if capacity == buffer.count {
        let localBuffer = buffer
        buffer.removeAll(keepingCapacity: true)
        locking.unlock()
        send(localBuffer)
      } else {
        locking.unlock()
      }
    }
  }
}

public extension Periodic {
  func delayedPeriodic(timeout: Double) -> InfiniteChannel<PeriodicValue> {
    return self.makeProducer(executor: .immediate) { (periodicValue: PeriodicValue, producer: InfiniteProducer<PeriodicValue>) -> Void in
      Executor.primary.execute(after: timeout) { [weak producer] in
        guard let producer = producer else { return }
        producer.send(periodicValue)
      }
    }
  }
}

public extension Periodic {
  func mapPeriodic<U: ExecutionContext, V>(context: U, executor: Executor? = nil,
                   transform: @escaping (U, PeriodicValue) -> V) -> InfiniteChannel<V> {
    return self.makeChannel(executor: executor ?? context.executor) { [weak context] (value, send) in
      guard let context = context else { return }
      send(transform(context, value))
    }
  }

  func onPeriodic<U: ExecutionContext>(context: U, executor: Executor? = nil,
                  block: @escaping (U, PeriodicValue) -> Void) {
    let handler = self.makePeriodicHandler(executor: executor ?? context.executor) { [weak context] (value) in
      guard let context = context else { return }
      block(context, value)
    }

    if let handler = handler {
      context.releaseOnDeinit(handler)
    }
  }
}

public extension Periodic where PeriodicValue : Finite {
  final func flatten(isOrdered: Bool = false) -> InfiniteChannel<Fallible<PeriodicValue.FinalValue>> {
    return self.makeProducer(executor: .immediate) { (periodicValue, producer) in
      let handler = periodicValue.makeFinalHandler(executor: .immediate) { [weak producer] (finalValue) in
        guard let producer = producer else { return }
        producer.send(finalValue)
      }
      if let handler = handler {
        producer.insertToReleasePool(handler)
      }
    }
  }
}
