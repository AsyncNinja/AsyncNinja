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

public class Channel<PeriodicValue> : Periodic {
  public typealias Value = PeriodicValue
  public typealias Handler = ChannelHandler<Value>
  public typealias PeriodicHandler = Handler

  init() { }

  public func makePeriodicHandler(executor: Executor,
                                    block: @escaping (PeriodicValue) -> Void) -> Handler? {
    /* abstract */
    fatalError()
  }
}

public extension Channel {
  func map<T>(executor: Executor = .primary,
           transform: @escaping (Value) -> T) -> Channel<T> {
    return self.mapPeriodic(executor: executor, transform: transform)
  }
  
  func onValue<U: ExecutionContext>(context: U, executor: Executor? = nil,
               block: @escaping (U, Value) -> Void) {
    self.onPeriodic(context: context, block: block)
  }

  func flatMap<T>(executor: Executor = .primary,
               transform: @escaping (Value) -> T?) -> Channel<T> {
    return self.flatMapPeriodic(executor: executor, transform: transform)
  }

  func flatMap<S: Sequence>(executor: Executor = .primary,
               transform: @escaping (Value) -> S) -> Channel<S.Iterator.Element> {
    return self.flatMapPeriodic(executor: executor, transform: transform)
  }

  func filter(executor: Executor = .immediate,
              predicate: @escaping (Value) -> Bool) -> Channel<Value> {
    return self.filterPeriodic(executor: executor, predicate: predicate)
  }

  func delayed(timeout: Double) -> Channel<PeriodicValue> {
    return self.delayedPeriodic(timeout: timeout)
  }
}

public extension Channel {
  func map<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                   transform: @escaping (U, Value) throws -> T) -> FiniteChannel<T, Void> {
    return self.mapPeriodic(context: context, executor: executor, cancellationToken: cancellationToken, transform: transform)
  }

  func flatMap<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
               transform: @escaping (U, Value) throws -> T?) -> FiniteChannel<T, Void> {
    return self.flatMapPeriodic(context: context, executor: executor, cancellationToken: cancellationToken, transform: transform)
  }

  func flatMap<S: Sequence, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
               transform: @escaping (U, Value) throws -> S) -> FiniteChannel<S.Iterator.Element, Void> {
    return self.flatMapPeriodic(context: context, executor: executor, cancellationToken: cancellationToken, transform: transform)
  }
}

/// **internal use only**
final public class ChannelHandler<T> {
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

extension Channel {
  func makeFiniteProducer<T>(executor: Executor, cancellationToken: CancellationToken?,
                          onPeriodic: @escaping (PeriodicValue, FiniteProducer<T, Void>) throws -> Void) -> FiniteProducer<T, Void> {
    let producer = FiniteProducer<T, Void>()
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
                          onPeriodic: @escaping (U, PeriodicValue, FiniteProducer<T, Void>) throws -> Void) -> FiniteProducer<T, Void> {
    let producer: FiniteProducer<T, Void> = self.makeFiniteProducer(executor: executor ?? context.executor, cancellationToken: cancellationToken) {
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

  func makeFiniteChannel<T>(executor: Executor, cancellationToken: CancellationToken?,
                         onPeriodic: @escaping (PeriodicValue, (T) throws -> Void) throws -> Void) -> FiniteChannel<T, Void> {
    return self.makeFiniteProducer(executor: executor, cancellationToken: cancellationToken) { (periodicValue: PeriodicValue, producer: FiniteProducer<T, Void>) -> Void in
      try onPeriodic(periodicValue) { producer.send($0) }
    }
  }

  func makeFiniteChannel<T, U: ExecutionContext>(context: U, executor: Executor?, cancellationToken: CancellationToken?,
                         onPeriodic: @escaping (U, PeriodicValue, (T) throws -> Void) throws -> Void) -> FiniteChannel<T, Void> {
    return self.makeFiniteProducer(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context, periodicValue, producer) -> Void in
      try onPeriodic(context, periodicValue) { producer.send($0) }
    }
  }
}

public extension Channel {
  func mapPeriodic<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                   transform: @escaping (U, PeriodicValue) throws -> T) -> FiniteChannel<T, Void> {
    return self.makeFiniteChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: Channel.PeriodicValue, send: (T) throws -> Void) in
      let transformedValue = try transform(context, periodicValue)
      try send(transformedValue)
    }
  }

  func flatMapPeriodic<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                       transform: @escaping (U, PeriodicValue) throws -> T?) -> FiniteChannel<T, Void> {
    return self.makeFiniteChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: Channel.PeriodicValue, send: (T) throws -> Void) in
      if let transformedValue = try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }

  func flatMapPeriodic<S: Sequence, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                       transform: @escaping (U, PeriodicValue) throws -> S) -> FiniteChannel<S.Iterator.Element, Void> {
    return self.makeFiniteChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: Channel.PeriodicValue, send: (S.Iterator.Element) throws -> Void) in
      for transformedValue in try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }
}
