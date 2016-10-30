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

public class Channel<PeriodicValue, FinalValue> : Periodic, Finite {
  public typealias Value = ChannelValue<PeriodicValue, FinalValue>
  public typealias Handler = ChannelHandler<PeriodicValue, FinalValue>
  public typealias PeriodicHandler = Handler
  public typealias FinalHandler = Handler

  public var finalValue: Fallible<FinalValue>? {
    /* abstact */
    fatalError()
  }

  init() { }

  final public func makeFinalHandler(executor: Executor,
                                     block: @escaping (Fallible<FinalValue>) -> Void) -> Handler? {
    return self.makeHandler(executor: executor) {
      if case .final(let value) = $0 { block(value) }
    }
  }

  public func next() -> PeriodicValue {
    fatalError()
  }

  final public func makePeriodicHandler(executor: Executor,
                                          block: @escaping (PeriodicValue) -> Void) -> Handler? {
    return self.makeHandler(executor: executor) {
      if case .periodic(let value) = $0 { block(value) }
    }
  }
  public func makeHandler(executor: Executor,
                          block: @escaping (Value) -> Void) -> Handler? {
    /* abstract */
    fatalError()
  }
  
  public func onValue<U: ExecutionContext>(context: U, executor: Executor? = nil,
                      block: @escaping (U, Value) -> Void) {
    let handler = self.makeHandler(executor: executor ?? context.executor) { [weak context] (value) in
      guard let context = context else { return }
      block(context, value)
    }
    
    if let handler = handler {
      context.releaseOnDeinit(handler)
    }
  }  
}

public enum ChannelValue<T, U> {
  public typealias PeriodicValue = T
  public typealias SuccessValue = U

  case periodic(PeriodicValue)
  case final(Fallible<SuccessValue>)
}

/// **internal use only**
final public class ChannelHandler<T, U> {
  public typealias PeriodicValue = T
  public typealias SuccessValue = U
  public typealias Value = ChannelValue<PeriodicValue, SuccessValue>

  let executor: Executor
  let block: (Value) -> Void

  public init(executor: Executor, block: @escaping (Value) -> Void) {
    self.executor = executor
    self.block = block
  }

  func handle(_ value: Value) {
    let block = self.block
    self.executor.execute { block(value) }
  }
}

// this code duplication from InfiniteChannel is a thing because parametrized associatedtype is not yet a thing.
extension Channel {
  func makeProducer<TransformedPeriodicValue, TransformedFinalValue>(
    executor: Executor, cancellationToken: CancellationToken?,
    onValue: @escaping (Value, Producer<TransformedPeriodicValue, TransformedFinalValue>) throws -> Void
    ) -> Producer<TransformedPeriodicValue, TransformedFinalValue> {
    let producer = Producer<TransformedPeriodicValue, TransformedFinalValue>()
    let handler = self.makeHandler(executor: executor) {
      [weak producer] (value) in
      guard let producer = producer else { return }
      do { try onValue(value, producer) }
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

  func makeProducer<TransformedPeriodicValue, TransformedFinalValue, U: ExecutionContext>(
    context: U, executor: Executor?, cancellationToken: CancellationToken?,
    onValue: @escaping (U, Value, Producer<TransformedPeriodicValue, TransformedFinalValue>) throws -> Void
    ) -> Producer<TransformedPeriodicValue, TransformedFinalValue> {
    let producer: Producer<TransformedPeriodicValue, TransformedFinalValue>
      = self.makeProducer(executor: executor ?? context.executor, cancellationToken: cancellationToken) {
        [weak context] (value, producer) in
        guard let context = context else { return }
        try onValue(context, value, producer)
    }
    context.notifyDeinit { [weak producer] (periodicValue) in
      guard let producer = producer else { return }
      producer.cancelBecauseOfDeallicatedContext()
    }
    return producer
  }
}

public extension Channel {
  func mapPeriodic<TransformedPeriodicValue, U: ExecutionContext>(
    context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
    transform: @escaping (U, PeriodicValue) throws -> TransformedPeriodicValue
    ) -> Channel<TransformedPeriodicValue, FinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context, value, producer) in
      switch value {
      case .periodic(let periodic):
        let transformedValue = try transform(context, periodic)
        producer.send(transformedValue)
      case .final(let final):
        producer.complete(with: final)
      }
    }
  }

  func mapPeriodic<TransformedPeriodicValue>(
    executor: Executor = .primary, cancellationToken: CancellationToken? = nil,
    transform: @escaping (PeriodicValue) throws -> TransformedPeriodicValue
    ) -> Channel<TransformedPeriodicValue, FinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken) {
      (value, producer) in
      switch value {
      case .periodic(let periodic):
        let transformedValue = try transform(periodic)
        producer.send(transformedValue)
      case .final(let final):
        producer.complete(with: final)
      }
    }
  }

  func flatMapPeriodic<TransformedPeriodicValue, U: ExecutionContext>(
    context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
    transform: @escaping (U, PeriodicValue) throws -> TransformedPeriodicValue?
    ) -> Channel<TransformedPeriodicValue, FinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context, value, producer) in
      switch value {
      case .periodic(let periodic):
        if let transformedValue = try transform(context, periodic) {
          producer.send(transformedValue)
        }
      case .final(let final):
        producer.complete(with: final)
      }
    }
  }

  func flatMapPeriodic<TransformedPeriodicValue>(
    executor: Executor = .primary, cancellationToken: CancellationToken? = nil,
    transform: @escaping (PeriodicValue) throws -> TransformedPeriodicValue?
    ) -> Channel<TransformedPeriodicValue, FinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken) {
      (value, producer) in
      switch value {
      case .periodic(let periodic):
        if let transformedValue = try transform(periodic) {
          producer.send(transformedValue)
        }
      case .final(let final):
        producer.complete(with: final)
      }
    }
  }

  func flatMapPeriodic<S: Sequence, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                       transform: @escaping (U, PeriodicValue) throws -> S) -> Channel<S.Iterator.Element, FinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context, value, producer) in
      switch value {
      case .periodic(let periodic):
        try transform(context, periodic).forEach(producer.send)
      case .final(let final):
        producer.complete(with: final)
      }
    }
  }

  func flatMapPeriodic<S: Sequence>(executor: Executor = .primary, cancellationToken: CancellationToken? = nil,
                       transform: @escaping (PeriodicValue) throws -> S) -> Channel<S.Iterator.Element, FinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken) {
      (value, producer) in
      switch value {
      case .periodic(let periodic):
        try transform(periodic).forEach(producer.send)
      case .final(let final):
        producer.complete(with: final)
      }
    }
  }
}

public extension Channel {
  func map<TransformedPeriodicValue, TransformedFinalValue, U: ExecutionContext>(
    context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
    transform: @escaping (U, Value) throws -> ChannelValue<TransformedPeriodicValue, TransformedFinalValue>
    ) -> Channel<TransformedPeriodicValue, TransformedFinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context, value, producer) in
      let transformedValue = try transform(context, value)
      producer.apply(transformedValue)
    }
  }

  func map<TransformedPeriodicValue, TransformedFinalValue>(
    executor: Executor = .primary, cancellationToken: CancellationToken? = nil,
    transform: @escaping (Value) throws -> ChannelValue<TransformedPeriodicValue, TransformedFinalValue>
    ) -> Channel<TransformedPeriodicValue, TransformedFinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken) {
      (value, producer) in
      let transformedValue = try transform(value)
      producer.apply(transformedValue)
    }
  }

  func flatMap<TransformedPeriodicValue, TransformedFinalValue, U: ExecutionContext>(
    context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
    transform: @escaping (U, Value) throws -> ChannelValue<TransformedPeriodicValue, TransformedFinalValue>?
    ) -> Channel<TransformedPeriodicValue, TransformedFinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context, value, producer) in
      if let transformedValue = try transform(context, value) {
        producer.apply(transformedValue)
      }
    }
  }

  func flatMap<TransformedPeriodicValue, TransformedFinalValue>(
    executor: Executor = .primary, cancellationToken: CancellationToken? = nil,
    transform: @escaping (Value) throws -> ChannelValue<TransformedPeriodicValue, TransformedFinalValue>?
    ) -> Channel<TransformedPeriodicValue, TransformedFinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken) {
      (value, producer) in
      if let transformedValue = try transform(value) {
        producer.apply(transformedValue)
      }
    }
  }
}
