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
                             onPeriodic: @escaping (PeriodicValue, Producer<T>) -> Void) -> Producer<T> {
    let producer = Producer<T>()
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
                            onPeriodic: @escaping (PeriodicValue, (T) -> Void) -> Void) -> Channel<T> {
    return self.makeProducer(executor: executor) { (periodicValue: PeriodicValue, producer: Producer<T>) -> Void in
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
                   transform: @escaping (PeriodicValue) -> T) -> Channel<T> {
    return self.makeChannel(executor: executor) { (PeriodicValue, send) in
      let transformedValue = transform(PeriodicValue)
      send(transformedValue)
    }
  }

  func flatMapPeriodic<T>(executor: Executor = .primary,
                         transform: @escaping (PeriodicValue) -> T?) -> Channel<T> {
    return self.makeChannel(executor: executor) { (PeriodicValue, send) in
      if let transformedValue = transform(PeriodicValue) {
        send(transformedValue)
      }
    }
  }

  func flatMapPeriodic<S: Sequence>(executor: Executor = .primary,
                         transform: @escaping (PeriodicValue) -> S) -> Channel<S.Iterator.Element> {
    return self.makeChannel(executor: executor) { (PeriodicValue, send) in
      transform(PeriodicValue).forEach(send)
    }
  }

  func filterPeriodic(executor: Executor = .immediate,
                        predicate: @escaping (PeriodicValue) -> Bool) -> Channel<PeriodicValue> {
    return self.makeChannel(executor: executor) { (PeriodicValue, send) in
      if predicate(PeriodicValue) {
        send(PeriodicValue)
      }
    }
  }

  func changes() -> Channel<(PeriodicValue?, PeriodicValue)> {
    var previousValue: PeriodicValue? = nil

    return self.makeChannel(executor: .immediate) { (value, send) in
      let change = (previousValue, value)
      previousValue = value
      send(change)
    }
  }

  #if os(Linux)
  func enumerated() -> Channel<(Int, PeriodicValue)> {
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
  func enumerated() -> Channel<(Int, PeriodicValue)> {
    var index: OSAtomic_int64_aligned64_t = -1
    return self.mapPeriodic(executor: .immediate) {
      let localIndex = Int(OSAtomicIncrement64(&index))
      return (localIndex, $0)
    }
  }
  #endif

  func bufferedPairs() -> Channel<(PeriodicValue, PeriodicValue)> {
    return self.buffered(capacity: 2).map(executor: .immediate) { ($0[0], $0[1]) }
  }

  func buffered(capacity: Int) -> Channel<[PeriodicValue]> {
    var buffer = [PeriodicValue]()
    buffer.reserveCapacity(capacity)
    let sema = DispatchSemaphore(value: 1)

    return self.makeChannel(executor: .immediate) { (PeriodicValue, send) in
      sema.wait()
      buffer.append(PeriodicValue)
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

public extension Periodic {
  func delayedPeriodic(timeout: Double) -> Channel<PeriodicValue> {
    return self.makeProducer(executor: .immediate) { (periodicValue: PeriodicValue, producer: Producer<PeriodicValue>) -> Void in
      Executor.primary.execute(after: timeout) { [weak producer] in
        guard let producer = producer else { return }
        producer.send(periodicValue)
      }
    }
  }
}

public extension Periodic {
  func mapPeriodic<U: ExecutionContext, V>(context: U, executor: Executor? = nil,
                   transform: @escaping (U, PeriodicValue) -> V) -> Channel<V> {
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

extension Periodic {
  func makeFiniteProducer<T>(executor: Executor, cancellationToken: CancellationToken?,
                          onPeriodic: @escaping (PeriodicValue, FiniteProducer<T, Error>) throws -> Void) -> FiniteProducer<T, Error> {
    let producer = FiniteProducer<T, Error>()
    let handler = self.makePeriodicHandler(executor: executor) { [weak producer] (periodicValue) in
      guard let producer = producer else { return }
      do { try onPeriodic(periodicValue, producer) }
      catch { producer.complete(with: error) }
    }

    if let handler = handler {
      producer.insertToReleasePool(handler)
    }

    if let cancellationToken = cancellationToken {
      cancellationToken.notifyCancellation { [weak producer] in
        producer?.complete(with: ConcurrencyError.cancelled)
      }
    }

    return producer
  }

  func makeFiniteProducer<T, U: ExecutionContext>(context: U, executor: Executor?, cancellationToken: CancellationToken?,
                          onPeriodic: @escaping (U, PeriodicValue, FiniteProducer<T, Error>) throws -> Void) -> FiniteProducer<T, Error> {
    let producer: FiniteProducer<T, Error> = self.makeFiniteProducer(executor: executor ?? context.executor, cancellationToken: cancellationToken) {
      [weak context] (periodicValue, producer) in
      guard let context = context else { return }
      try onPeriodic(context, periodicValue, producer)
    }
    context.notifyDeinit { [weak producer] (periodicValue) in
      guard let producer = producer else { return }
      producer.complete(with: ConcurrencyError.contextDeallocated)
    }
    return producer
  }

  func makeFiniteChannel<T>(executor: Executor, cancellationToken: CancellationToken?,
                         onPeriodic: @escaping (PeriodicValue, (T) throws -> Void) throws -> Void) -> FiniteChannel<T, Error> {
    return self.makeFiniteProducer(executor: executor, cancellationToken: cancellationToken) { (periodicValue: PeriodicValue, producer: FiniteProducer<T, Error>) -> Void in
      try onPeriodic(periodicValue) { producer.send($0) }
    }
  }

  func makeFiniteChannel<T, U: ExecutionContext>(context: U, executor: Executor?, cancellationToken: CancellationToken?,
                         onPeriodic: @escaping (U, PeriodicValue, (T) throws -> Void) throws -> Void) -> FiniteChannel<T, Error> {
    return self.makeFiniteProducer(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context, periodicValue, producer) -> Void in
      try onPeriodic(context, periodicValue) { producer.send($0) }
    }
  }
}

public extension Periodic {
  func mapPeriodic<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
           transform: @escaping (U, PeriodicValue) throws -> T) -> FiniteChannel<T, Error> {
    return self.makeFiniteChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: Channel.PeriodicValue, send: (T) throws -> Void) in
      let transformedValue = try transform(context, periodicValue)
      try send(transformedValue)
    }
  }

  func flatMapPeriodic<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
               transform: @escaping (U, PeriodicValue) throws -> T?) -> FiniteChannel<T, Error> {
    return self.makeFiniteChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: Channel.PeriodicValue, send: (T) throws -> Void) in
      if let transformedValue = try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }

  func flatMapPeriodic<S: Sequence, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
               transform: @escaping (U, PeriodicValue) throws -> S) -> FiniteChannel<S.Iterator.Element, Error> {
    return self.makeFiniteChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: Channel.PeriodicValue, send: (S.Iterator.Element) throws -> Void) in
      for transformedValue in try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }
}
