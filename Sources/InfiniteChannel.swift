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

public class InfiniteChannel<PeriodicValue> : Periodic {
  public typealias Value = PeriodicValue
  public typealias Handler = InfiniteChannelHandler<Value>
  public typealias PeriodicHandler = Handler

  init() { }

  public func makePeriodicHandler(executor: Executor,
                                  block: @escaping (PeriodicValue) -> Void) -> Handler? {
    /* abstract */
    fatalError()
  }
}

public extension InfiniteChannel {
  func map<TransformedValue>(executor: Executor = .primary,
           transform: @escaping (Value) -> TransformedValue) -> InfiniteChannel<TransformedValue> {
    return self.mapPeriodic(executor: executor, transform: transform)
  }

  func map<TransformedValue, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
           transform: @escaping (U, Value) throws -> TransformedValue) -> Channel<TransformedValue, Void> {
    return self.mapPeriodic(context: context, executor: executor, cancellationToken: cancellationToken, transform: transform)
  }

  func onValue<U: ExecutionContext>(context: U, executor: Executor? = nil,
               block: @escaping (U, Value) -> Void) {
    self.onPeriodic(context: context, block: block)
  }

  func flatMap<T>(executor: Executor = .primary,
               transform: @escaping (Value) -> T?) -> InfiniteChannel<T> {
    return self.flatMapPeriodic(executor: executor, transform: transform)
  }

  func flatMap<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
               transform: @escaping (U, Value) throws -> T?) -> Channel<T, Void> {
    return self.flatMapPeriodic(context: context, executor: executor, cancellationToken: cancellationToken, transform: transform)
  }

  func flatMap<S: Sequence>(executor: Executor = .primary,
               transform: @escaping (Value) -> S) -> InfiniteChannel<S.Iterator.Element> {
    return self.flatMapPeriodic(executor: executor, transform: transform)
  }

  func flatMap<S: Sequence, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
               transform: @escaping (U, Value) throws -> S) -> Channel<S.Iterator.Element, Void> {
    return self.flatMapPeriodic(context: context, executor: executor, cancellationToken: cancellationToken, transform: transform)
  }

  func filter(executor: Executor = .immediate,
              predicate: @escaping (Value) -> Bool) -> InfiniteChannel<Value> {
    return self.filterPeriodic(executor: executor, predicate: predicate)
  }

  func delayed(timeout: Double) -> InfiniteChannel<PeriodicValue> {
    return self.delayedPeriodic(timeout: timeout)
  }
}

/// **internal use only**
final public class InfiniteChannelHandler<T> {
  public typealias PeriodicValue = T

  let executor: Executor
  let block: (PeriodicValue) -> Void

  public init(executor: Executor,
              block: @escaping (PeriodicValue) -> Void) {
    self.executor = executor
    self.block = block
  }

  func handle(_ value: PeriodicValue) {
    let block = self.block
    self.executor.execute { block(value) }
  }
}

extension InfiniteChannel {
  func makeFiniteProducer<T>(executor: Executor, cancellationToken: CancellationToken?,
                          onPeriodic: @escaping (PeriodicValue, Producer<T, Void>) throws -> Void) -> Producer<T, Void> {
    let producer = Producer<T, Void>()
    let handler = self.makePeriodicHandler(executor: executor) { [weak producer] (periodicValue) in
      guard let producer = producer else { return }
      do { try onPeriodic(periodicValue, producer) }
      catch { producer.fail(with: error) }
    }

    if let handler = handler {
      producer.insertToReleasePool(handler)
    }

    if let cancellationToken = cancellationToken {
      cancellationToken.notifyCancellation { [weak producer] in
        producer?.cancel()
      }
    }

    return producer
  }

  func makeFiniteProducer<T, U: ExecutionContext>(context: U, executor: Executor?, cancellationToken: CancellationToken?,
                          onPeriodic: @escaping (U, PeriodicValue, Producer<T, Void>) throws -> Void) -> Producer<T, Void> {
    let producer: Producer<T, Void> = self.makeFiniteProducer(executor: executor ?? context.executor, cancellationToken: cancellationToken) {
      [weak context] (periodicValue, producer) in
      guard let context = context else { return }
      try onPeriodic(context, periodicValue, producer)
    }
    context.notifyDeinit { [weak producer] (periodicValue) in
      guard let producer = producer else { return }
      producer.cancelBecauseOfDeallicatedContext()
    }
    return producer
  }

  func makeChannel<T>(executor: Executor, cancellationToken: CancellationToken?,
                         onPeriodic: @escaping (PeriodicValue, (T) throws -> Void) throws -> Void) -> Channel<T, Void> {
    return self.makeFiniteProducer(executor: executor, cancellationToken: cancellationToken) { (periodicValue: PeriodicValue, producer: Producer<T, Void>) -> Void in
      try onPeriodic(periodicValue) { producer.send($0) }
    }
  }

  func makeChannel<T, U: ExecutionContext>(context: U, executor: Executor?, cancellationToken: CancellationToken?,
                         onPeriodic: @escaping (U, PeriodicValue, (T) throws -> Void) throws -> Void) -> Channel<T, Void> {
    return self.makeFiniteProducer(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context, periodicValue, producer) -> Void in
      try onPeriodic(context, periodicValue) { producer.send($0) }
    }
  }
}

public extension InfiniteChannel {
  func mapPeriodic<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                   transform: @escaping (U, PeriodicValue) throws -> T) -> Channel<T, Void> {
    return self.makeChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: InfiniteChannel.PeriodicValue, send: (T) throws -> Void) in
      let transformedValue = try transform(context, periodicValue)
      try send(transformedValue)
    }
  }

  func flatMapPeriodic<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                       transform: @escaping (U, PeriodicValue) throws -> T?) -> Channel<T, Void> {
    return self.makeChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: InfiniteChannel.PeriodicValue, send: (T) throws -> Void) in
      if let transformedValue = try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }

  func flatMapPeriodic<S: Sequence, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                       transform: @escaping (U, PeriodicValue) throws -> S) -> Channel<S.Iterator.Element, Void> {
    return self.makeChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: InfiniteChannel.PeriodicValue, send: (S.Iterator.Element) throws -> Void) in
      for transformedValue in try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }
}
