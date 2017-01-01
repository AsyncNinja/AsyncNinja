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

  /// **internal use only**
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

  /// **internal use only**
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
      producer.cancelBecauseOfDeallocatedContext()
    }
    return producer
  }
}

// MARK: - whole channel transformations
public extension Channel {

  /// Applies transformation to the whole channel. `mapPeriodic` methods are more convenient if you want to transform periodics values only.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor. Do not use this argument if you do not need to override executor
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  ///   - transform: to apply
  ///   - strongContext: context restored from weak reference to specified context
  ///   - value: `ChannelValue` to transform. May be either periodic or final
  /// - Returns: transformed channel
  func map<TransformedPeriodicValue, TransformedFinalValue, U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (_ strongContext: U, _ value: Value) throws -> ChannelValue<TransformedPeriodicValue, TransformedFinalValue>
    ) -> Channel<TransformedPeriodicValue, TransformedFinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (context, value, producer) in
      let transformedValue = try transform(context, value)
      producer.apply(transformedValue)
    }
  }

  /// Applies transformation to the whole channel. `mapPeriodic` methods are more convenient if you want to transform periodics values only.
  ///
  /// - Parameters:
  ///   - executor: to execute transform on
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  ///   - transform: to apply
  ///   - value: `ChannelValue` to transform. May be either periodic or final
  /// - Returns: transformed channel
  func map<TransformedPeriodicValue, TransformedFinalValue>(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (_ value: Value) throws -> ChannelValue<TransformedPeriodicValue, TransformedFinalValue>
    ) -> Channel<TransformedPeriodicValue, TransformedFinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (value, producer) in
      let transformedValue = try transform(value)
      producer.apply(transformedValue)
    }
  }
}

// MARK: - periodics only transformations

public extension Channel {

  /// Applies transformation to periodic values of the channel. `map` methods are more convenient if you want to transform both periodics and final value
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor. Do not use this argument if you do not need to override executor
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  ///   - transform: to apply
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func mapPeriodic<TransformedPeriodicValue, U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (_ strongContext: U, _ periodicValue: PeriodicValue) throws -> TransformedPeriodicValue
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

  /// Applies transformation to periodic values of the channel. `map` methods are more convenient if you want to transform both periodics and final value
  ///
  /// - Parameters:
  ///   - executor: to execute transform on
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  ///   - transform: to apply
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func mapPeriodic<TransformedPeriodicValue>(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (_ periodicValue: PeriodicValue) throws -> TransformedPeriodicValue
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
}

// MARK: - periodics only flattening transformations

public extension Channel {

  /// Applies transformation to periodic values of the channel.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor. Do not use this argument if you do not need to override executor
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  ///   - transform: to apply. Nil returned from transform will not produce periodic value
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func flatMapPeriodic<TransformedPeriodicValue, U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (_ strongContext: U, _ periodicValue: PeriodicValue) throws -> TransformedPeriodicValue?
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

  /// Applies transformation to periodic values of the channel.
  ///
  /// - Parameters:
  ///   - executor: to execute transform on
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  ///   - transform: to apply. Nil returned from transform will not produce periodic value
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func flatMapPeriodic<TransformedPeriodicValue>(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (_ periodicValue: PeriodicValue) throws -> TransformedPeriodicValue?
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

  /// Applies transformation to periodic values of the channel.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor. Do not use this argument if you do not need to override executor
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  ///   - transform: to apply. Sequence returned from transform will be treated as multiple period values
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func flatMapPeriodic<S: Sequence, U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (_ strongContext: U, _ periodicValue: PeriodicValue) throws -> S
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

  /// Applies transformation to periodic values of the channel.
  ///
  /// - Parameters:
  ///   - executor: to execute transform on
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  ///   - transform: to apply. Sequence returned from transform will be treated as multiple period values
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func flatMapPeriodic<S: Sequence>(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (_ periodicValue: PeriodicValue) throws -> S
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

  /// Applies transformation to periodic values of the channel.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor. Do not use this argument if you do not need to override executor
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  ///   - transform: to apply. Completion of a future will be used as periodic value of transformed channel
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func flatMapPeriodic<T, U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (_ strongContext: U, _ periodicValue: PeriodicValue) throws -> Future<T>
    ) -> Channel<Fallible<T>, FinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (context, value, producer) in
      switch value {
      case .periodic(let periodic):
        let handler = (try transform(context, periodic))
          .makeFinalHandler(executor: .immediate) { [weak producer] (periodic) -> Void in
            producer?.send(periodic)

        }
        if let handler = handler {
          producer.insertToReleasePool(handler)
        }
      case .final(let final):
        producer.complete(with: final)
      }
    }
  }

  /// Applies transformation to periodic values of the channel.
  ///
  /// - Parameters:
  ///   - executor: to execute transform on
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  ///   - transform: to apply. Completion of a future will be used as periodic value of transformed channel
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func flatMapPeriodic<T>(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    transform: @escaping (_ periodicValue: PeriodicValue) throws -> Future<T>
    ) -> Channel<Fallible<T>, FinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (value, producer) in
      switch value {
      case .periodic(let periodic):
        let handler = (try transform(periodic))
          .makeFinalHandler(executor: .immediate) { [weak producer] (periodic) -> Void in
            producer?.send(periodic)

        }
        if let handler = handler {
          producer.insertToReleasePool(handler)
        }
      case .final(let final):
        producer.complete(with: final)
      }
    }
  }
}

// MARK: convenient transformations

public extension Channel {

  /// Filters periodic values of the channel
  ///
  ///   - context: `ExectionContext` to apply predicate in
  ///   - executor: override of `ExecutionContext`s executor. Do not use this argument if you do not need to override executor
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  ///   - predicate: to apply
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: filtered transform
  func filterPeriodic<U: ExecutionContext>(
    context: U,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    predicate: @escaping (_ strongContext: U, _ periodicValue: PeriodicValue) throws -> Bool
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

  /// Filters periodic values of the channel
  ///
  ///   - executor: to execute transform on
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  ///   - predicate: to apply
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: filtered transform
  func filterPeriodic(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    predicate: @escaping (_ periodicValue: PeriodicValue) throws -> Bool
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

  #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

  /// Adds indexes to periodic values of the channel
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  /// - Returns: channel with tuple (index, periodicValue) as periodic value
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
  #else

  /// Adds indexes to periodic values of the channel
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  /// - Returns: channel with tuple (index, periodicValue) as periodic value
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
  #endif

  /// Makes channel of pairs of periodic values
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  /// - Returns: channel with tuple (periodicValue, periodicValue) as periodic value
  func bufferedPairs(
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

  /// Makes channel of arrays of periodic values
  ///
  /// - Parameters:
  ///   - capacity: number of periodic values of original channel used as periodic value of derived channel
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  /// - Returns: channel with [periodicValue] as periodic value
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

  /// Makes channel that delays each value produced by originial channel
  ///
  /// - Parameters:
  ///   - timeout: in seconds to delay original channel by
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  /// - Returns: delayed channel
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

extension Channel where PeriodicValue : Equatable {

  /// Returns channel of distinct periodic values of original channel. Works only for equatable periodic values [0, 0, 1, 2, 3, 3, 4, 3] => [0, 1, 2, 3, 4, 3]
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  /// - Returns: channel with distinct periodic values
  public func distinct(
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

        if let previousPeriodic = _previousPeriodic,
          previousPeriodic != periodic {
          let change = (previousPeriodic, periodic)
          producer.send(change)
        }
      case let .final(final):
        producer.complete(with: final)
      }
    }
  }
}
