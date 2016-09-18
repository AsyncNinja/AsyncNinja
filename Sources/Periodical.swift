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

public protocol Periodical : class {
  associatedtype Value
  associatedtype PeriodicalValue
  associatedtype PeriodicalHandler : AnyObject

  /// **internal use only**
  func makePeriodicalHandler(executor: Executor,
                             block: @escaping (PeriodicalValue) -> Void) -> PeriodicalHandler?
}

public extension Periodical {
  internal func makeProducer<T>(executor: Executor,
                             onPeriodic: @escaping (PeriodicalValue, Producer<T>) -> Void) -> Producer<T> {
    let producer = Producer<T>()
    let handler = self.makePeriodicalHandler(executor: executor) { [weak producer] (periodicalValue) in
      guard let producer = producer else { return }
      onPeriodic(periodicalValue, producer)
    }

    if let handler = handler {
      producer.releasePool.insert(handler)
    }
    return producer
  }

  internal func makeChannel<T>(executor: Executor,
                            onPeriodic: @escaping (PeriodicalValue, (T) -> Void) -> Void) -> Channel<T> {
    return self.makeProducer(executor: executor) { (periodicalValue: PeriodicalValue, producer: Producer<T>) -> Void in
      onPeriodic(periodicalValue, producer.send)
    }
  }

  func next() -> PeriodicalValue {
    return self.next(waitingBlock: { $0.wait(); return .success })!
  }

  func next(timeout: DispatchTime) -> PeriodicalValue? {
    return self.next(waitingBlock: { $0.wait(timeout: timeout) })
  }

  func next(wallTimeout: DispatchWallTime) -> PeriodicalValue? {
    return self.next(waitingBlock: { $0.wait(wallTimeout: wallTimeout) })
  }

  internal func next(waitingBlock: (DispatchSemaphore) -> DispatchTimeoutResult) -> PeriodicalValue? {
    let sema = DispatchSemaphore(value: 0)
    var result: PeriodicalValue? = nil

    var handler: PeriodicalHandler? = self.makePeriodicalHandler(executor: .immediate) {
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
                   transform: @escaping (PeriodicalValue) -> T) -> Channel<T> {
    return self.makeChannel(executor: executor) { (PeriodicalValue, send) in
      let transformedValue = transform(PeriodicalValue)
      send(transformedValue)
    }
  }

  func flatMapPeriodical<T>(executor: Executor = .primary,
                         transform: @escaping (PeriodicalValue) -> T?) -> Channel<T> {
    return self.makeChannel(executor: executor) { (PeriodicalValue, send) in
      if let transformedValue = transform(PeriodicalValue) {
        send(transformedValue)
      }
    }
  }

  func flatMapPeriodical<S: Sequence>(executor: Executor = .primary,
                         transform: @escaping (PeriodicalValue) -> S) -> Channel<S.Iterator.Element> {
    return self.makeChannel(executor: executor) { (PeriodicalValue, send) in
      transform(PeriodicalValue).forEach(send)
    }
  }

  func filterPeriodical(executor: Executor = .immediate,
                        predicate: @escaping (PeriodicalValue) -> Bool) -> Channel<PeriodicalValue> {
    return self.makeChannel(executor: executor) { (PeriodicalValue, send) in
      if predicate(PeriodicalValue) {
        send(PeriodicalValue)
      }
    }
  }

  func changes() -> Channel<(PeriodicalValue?, PeriodicalValue)> {
    var previousValue: PeriodicalValue? = nil

    return self.makeChannel(executor: .immediate) { (value, send) in
      let change = (previousValue, value)
      previousValue = value
      send(change)
    }
  }

  #if os(Linux)
  func enumerated() -> Channel<(Int, PeriodicalValue)> {
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
  func enumerated() -> Channel<(Int, PeriodicalValue)> {
    var index: OSAtomic_int64_aligned64_t = -1
    return self.mapPeriodic(executor: .immediate) {
      let localIndex = Int(OSAtomicIncrement64(&index))
      return (localIndex, $0)
    }
  }
  #endif

  func bufferedPairs() -> Channel<(PeriodicalValue, PeriodicalValue)> {
    return self.buffered(capacity: 2).map(executor: .immediate) { ($0[0], $0[1]) }
  }

  func buffered(capacity: Int) -> Channel<[PeriodicalValue]> {
    var buffer = [PeriodicalValue]()
    buffer.reserveCapacity(capacity)
    let sema = DispatchSemaphore(value: 1)

    return self.makeChannel(executor: .immediate) { (PeriodicalValue, send) in
      sema.wait()
      buffer.append(PeriodicalValue)
      if capacity == buffer.count {
        let localBuffer = buffer
        buffer.removeAll(keepingCapacity: true)
        sema.signal()
        send(localBuffer)
      } else {
        sema.signal()
      }
    }
  }
}

public extension Periodical {
  func delayedPeriodical(timeout: Double) -> Channel<PeriodicalValue> {
    return self.makeProducer(executor: .immediate) { (periodicalValue: PeriodicalValue, producer: Producer<PeriodicalValue>) -> Void in
      Executor.primary.execute(after: timeout) { [weak producer] in
        guard let producer = producer else { return }
        producer.send(periodicalValue)
      }
    }
  }
}

public extension Periodical {
  func mapPeriodic<U: ExecutionContext, V>(context: U, executor: Executor? = nil,
                   transform: @escaping (U, PeriodicalValue) -> V) -> Channel<V> {
    return self.makeChannel(executor: executor ?? context.executor) { [weak context] (value, send) in
      guard let context = context else { return }
      send(transform(context, value))
    }
  }

  func onPeriodic<U: ExecutionContext>(context: U, executor: Executor? = nil,
                  block: @escaping (U, PeriodicalValue) -> Void) {
    let handler = self.makePeriodicalHandler(executor: executor ?? context.executor) { [weak context] (value) in
      guard let context = context else { return }
      block(context, value)
    }

    if let handler = handler {
      context.releaseOnDeinit(handler)
    }
  }
}
