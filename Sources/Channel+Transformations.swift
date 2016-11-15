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

// MARK: - internal methods that produce derived producers and channels
extension Channel {
  func makeProducer<TransformedPeriodicValue, TransformedFinalValue>(
    executor: Executor,
    cancellationToken: CancellationToken?,
    bufferSize: DerivedChannelBufferSize,
    onValue: @escaping (Value, Producer<TransformedPeriodicValue, TransformedFinalValue>) throws -> Void
    ) -> Producer<TransformedPeriodicValue, TransformedFinalValue> {
    let bufferSize = bufferSize.bufferSize(for: self)
    let producer = Producer<TransformedPeriodicValue, TransformedFinalValue>(bufferSize: bufferSize)
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
    context: U,
    executor: Executor?,
    cancellationToken: CancellationToken?,
    bufferSize: DerivedChannelBufferSize,
    onValue: @escaping (U, Value, Producer<TransformedPeriodicValue, TransformedFinalValue>
    ) throws -> Void
    ) -> Producer<TransformedPeriodicValue, TransformedFinalValue> {
    let producer: Producer<TransformedPeriodicValue, TransformedFinalValue>
      = self.makeProducer(executor: executor ?? context.executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
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

// MARK: - whole channel transformations
public extension Channel {
  func map<TransformedPeriodicValue, TransformedFinalValue, U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (U, Value) throws -> ChannelValue<TransformedPeriodicValue, TransformedFinalValue>
    ) -> Channel<TransformedPeriodicValue, TransformedFinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (context, value, producer) in
      let transformedValue = try transform(context, value)
      producer.apply(transformedValue)
    }
  }

  func map<TransformedPeriodicValue, TransformedFinalValue>(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (Value) throws -> ChannelValue<TransformedPeriodicValue, TransformedFinalValue>
    ) -> Channel<TransformedPeriodicValue, TransformedFinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (value, producer) in
      let transformedValue = try transform(value)
      producer.apply(transformedValue)
    }
  }

  func flatMap<TransformedPeriodicValue, TransformedFinalValue, U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (U, Value) throws -> ChannelValue<TransformedPeriodicValue, TransformedFinalValue>?
    ) -> Channel<TransformedPeriodicValue, TransformedFinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (context, value, producer) in
      if let transformedValue = try transform(context, value) {
        producer.apply(transformedValue)
      }
    }
  }

  func flatMap<TransformedPeriodicValue, TransformedFinalValue>(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (Value) throws -> ChannelValue<TransformedPeriodicValue, TransformedFinalValue>?
    ) -> Channel<TransformedPeriodicValue, TransformedFinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (value, producer) in
      if let transformedValue = try transform(value) {
        producer.apply(transformedValue)
      }
    }
  }
}

// MARK: - periodics only transformations
public extension Channel {
  func mapPeriodic<TransformedPeriodicValue, U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (U, PeriodicValue) throws -> TransformedPeriodicValue
    ) -> Channel<TransformedPeriodicValue, FinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
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
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (PeriodicValue) throws -> TransformedPeriodicValue
    ) -> Channel<TransformedPeriodicValue, FinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
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
    context: U,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (U, PeriodicValue) throws -> TransformedPeriodicValue?
    ) -> Channel<TransformedPeriodicValue, FinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
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
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (PeriodicValue) throws -> TransformedPeriodicValue?
    ) -> Channel<TransformedPeriodicValue, FinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
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

  func flatMapPeriodic<S: Sequence, U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (U, PeriodicValue) throws -> S
    ) -> Channel<S.Iterator.Element, FinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (context, value, producer) in
      switch value {
      case .periodic(let periodic):
        try transform(context, periodic).forEach(producer.send)
      case .final(let final):
        producer.complete(with: final)
      }
    }
  }

  func flatMapPeriodic<S: Sequence>(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (PeriodicValue) throws -> S
    ) -> Channel<S.Iterator.Element, FinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (value, producer) in
      switch value {
      case .periodic(let periodic):
        try transform(periodic).forEach(producer.send)
      case .final(let final):
        producer.complete(with: final)
      }
    }
  }

  func filterPeriodic<U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    predicate: @escaping (U, PeriodicValue) throws -> Bool
    ) -> Channel<PeriodicValue, FinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (context, value, producer) in
      switch value {
      case .periodic(let periodic):
        do {
          if try predicate(context, periodic) {
            producer.send(periodic)
          }
        } catch { producer.fail(with: error) }
      case .final(let final):
        producer.complete(with: final)
      }
    }
  }

  func filterPeriodic(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    predicate: @escaping (PeriodicValue) throws -> Bool
    ) -> Channel<PeriodicValue, FinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (value, producer) in
      switch value {
      case .periodic(let periodic):
        do {
          if try predicate(periodic) {
            producer.send(periodic)
          }
        } catch { producer.fail(with: error) }
      case .final(let final):
        producer.complete(with: final)
      }
    }
  }

  func changes(
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<(PeriodicValue, PeriodicValue), FinalValue> {
    var locking = makeLocking()
    var previousPeriodic: PeriodicValue? = nil

    return self.makeProducer(executor: .immediate, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (value, producer) in
      switch value {
      case let .periodic(periodic):
        locking.lock()
        let _previousPeriodic = previousPeriodic
        previousPeriodic = periodic
        locking.unlock()

        if let previousPeriodic = _previousPeriodic {
          let change = (previousPeriodic, periodic)
          producer.send(change)
        }
      case let .final(final):
        producer.complete(with: final)
      }
    }
  }

  #if os(Linux)
  func enumerated(
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<(Int, PeriodicValue), FinalValue> {
    var locking = makeLocking()
    var index = 0
    return self.mapPeriodic(executor: .immediate, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      locking.lock()
      defer { locking.unlock() }
      let localIndex = index
      index += 1
      return (localIndex, $0)
    }
  }
  #else
  func enumerated(
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<(Int, PeriodicValue), FinalValue> {
    var index: OSAtomic_int64_aligned64_t = -1
    return self.mapPeriodic(executor: .immediate, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      let localIndex = Int(OSAtomicIncrement64(&index))
      return (localIndex, $0)
    }
  }
  #endif

  func bufferedPairs(
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<(PeriodicValue, PeriodicValue), FinalValue> {
    return self.buffered(capacity: 2, cancellationToken: cancellationToken, bufferSize: bufferSize).map(executor: .immediate) {
      switch $0 {
      case let .periodic(periodic):
        return .periodic((periodic[0], periodic[1]))
      case let .final(final):
        return .final(final)
      }
    }
  }

  func buffered(
    capacity: Int,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<[PeriodicValue], FinalValue> {
    var buffer = [PeriodicValue]()
    buffer.reserveCapacity(capacity)
    var locking = makeLocking()

    return self.makeProducer(executor: .immediate, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (value, producer) in
      locking.lock()

      switch value {
      case let .periodic(periodic):
        buffer.append(periodic)
        if capacity == buffer.count {
          let localBuffer = buffer
          buffer.removeAll(keepingCapacity: true)
          locking.unlock()
          producer.send(localBuffer)
        } else {
          locking.unlock()
        }
      case let .final(final):
        let localBuffer = buffer
        buffer.removeAll(keepingCapacity: false)
        locking.unlock()

        if !localBuffer.isEmpty {
          producer.send(localBuffer)
        }
        producer.complete(with: final)
      }
    }
  }

  func delayedPeriodic(
    timeout: Double,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<PeriodicValue, FinalValue> {
    return self.makeProducer(executor: .immediate, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (value: Value, producer: Producer<PeriodicValue, FinalValue>) -> Void in
      Executor.primary.execute(after: timeout) { [weak producer] in
        guard let producer = producer else { return }
        producer.apply(value)
      }
    }
  }
}
