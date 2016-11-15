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

public class Channel<PeriodicValue, FinalValue> : Finite {
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

public extension Channel {
  internal func makeProducer<T, U>(executor: Executor,
                             onValue: @escaping (Value, Producer<T, U>) -> Void) -> Producer<T, U> {
    let producer = Producer<T, U>()
    let handler = self.makeHandler(executor: executor) { [weak producer] (value) in
      guard let producer = producer else { return }
      onValue(value, producer)
    }

    if let handler = handler {
      producer.insertToReleasePool(handler)
    }
    return producer
  }

  internal func makeChannel<T, U>(executor: Executor,
                            onValue: @escaping (Value, (ChannelValue<T, U>) -> Void) -> Void) -> Channel<T, U> {
    return self.makeProducer(executor: executor) { (value: Value, producer: Producer<T, U>) -> Void in
      onValue(value, producer.apply)
    }
  }

  func flatMapPeriodic<T>(executor: Executor = .primary,
                         transform: @escaping (PeriodicValue) -> T?) -> Channel<T, FinalValue> {
    return self.makeChannel(executor: executor) { (value, send) in
      switch value {
      case let .periodic(periodic):
        if let transformedValue = transform(periodic) {
          send(.periodic(transformedValue))
        }
      case let .final(final):
        send(.final(final))
      }
    }
  }

  func flatMapPeriodic<S: Sequence>(executor: Executor = .primary,
                         transform: @escaping (PeriodicValue) -> S) -> Channel<S.Iterator.Element, FinalValue> {
    return self.makeChannel(executor: executor) { (value, send) in
      switch value {
      case let .periodic(periodic):
        for transformedValue in transform(periodic) {
          send(.periodic(transformedValue))
        }
      case let .final(final):
        send(.final(final))
      }
    }
  }

  func filterPeriodic(executor: Executor = .immediate,
                        predicate: @escaping (PeriodicValue) -> Bool) -> Channel<PeriodicValue, FinalValue> {
    return self.makeChannel(executor: executor) { (value, send) in
      switch value {
      case let .periodic(periodic):
        if predicate(periodic) {
          send(.periodic(periodic))
        }
      case let .final(final):
        send(.final(final))
      }
    }
  }

  func changes() -> Channel<(PeriodicValue, PeriodicValue), FinalValue> {
    var locking = makeLocking()
    var previousPeriodic: PeriodicValue? = nil

    return self.makeChannel(executor: .immediate) { (value, send) in
      switch value {
      case let .periodic(periodic):
        locking.lock()
        let _previousPeriodic = previousPeriodic
        previousPeriodic = periodic
        locking.unlock()

        if let previousPeriodic = _previousPeriodic {
          let change = (previousPeriodic, periodic)
          send(.periodic(change))
        }
      case let .final(final):
        send(.final(final))
      }
    }
  }

  #if os(Linux)
  func enumerated() -> Channel<(Int, PeriodicValue), FinalValue> {
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
  func enumerated() -> Channel<(Int, PeriodicValue), FinalValue> {
    var index: OSAtomic_int64_aligned64_t = -1
    return self.mapPeriodic(executor: .immediate) {
      let localIndex = Int(OSAtomicIncrement64(&index))
      return (localIndex, $0)
    }
  }
  #endif

  func bufferedPairs() -> Channel<(PeriodicValue, PeriodicValue), FinalValue> {
    return self.buffered(capacity: 2).map(executor: .immediate) {
      switch $0 {
      case let .periodic(periodic):
        return .periodic((periodic[0], periodic[1]))
      case let .final(final):
        return .final(final)
      }
    }
  }

  func buffered(capacity: Int) -> Channel<[PeriodicValue], FinalValue> {
    var buffer = [PeriodicValue]()
    buffer.reserveCapacity(capacity)
    var locking = makeLocking()

    return self.makeChannel(executor: .immediate) { (value, send) in
      locking.lock()

      switch value {
      case let .periodic(periodic):
        buffer.append(periodic)
        if capacity == buffer.count {
          let localBuffer = buffer
          buffer.removeAll(keepingCapacity: true)
          locking.unlock()
          send(.periodic(localBuffer))
        } else {
          locking.unlock()
        }
      case let .final(final):
        let localBuffer = buffer
        buffer.removeAll(keepingCapacity: false)
        locking.unlock()

        if !localBuffer.isEmpty {
          send(.periodic(localBuffer))
        }
        send(.final(final))
      }
    }
  }
}

public extension Channel {
  func delayedPeriodic(timeout: Double) -> Channel<PeriodicValue, FinalValue> {
    return self.makeProducer(executor: .immediate) { (value: Value, producer: Producer<PeriodicValue, FinalValue>) -> Void in
      Executor.primary.execute(after: timeout) { [weak producer] in
        guard let producer = producer else { return }
        producer.apply(value)
      }
    }
  }
}

public extension Channel {
  func mapPeriodic<U: ExecutionContext, V>(context: U, executor: Executor? = nil,
                   transform: @escaping (U, PeriodicValue) -> V) -> Channel<V, FinalValue> {
    return self.makeChannel(executor: executor ?? context.executor) { [weak context] (value, send) in
      guard let context = context else { return }
      switch value {
      case let .periodic(periodic):
        send(.periodic(transform(context, periodic)))
      case let .final(final):
        send(.final(final))
      }
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

//public extension Channel where PeriodicValue : Finite {
//  final func flatten(isOrdered: Bool = false) -> Channel<Fallible<PeriodicValue.FinalValue>> {
//    return self.makeProducer(executor: .immediate) { (periodicValue, producer) in
//      let handler = periodicValue.makeFinalHandler(executor: .immediate) { [weak producer] (finalValue) in
//        guard let producer = producer else { return }
//        producer.send(finalValue)
//      }
//      if let handler = handler {
//        producer.insertToReleasePool(handler)
//      }
//    }
//  }
//}
