//
//  Copyright (c) 2016-2017 Anton Mironov
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
  func makeProducer<P, S>(executor: Executor,
                    cancellationToken: CancellationToken?,
                    bufferSize: DerivedChannelBufferSize,
                    onValue: @escaping (Value, Producer<P, S>) throws -> Void
    ) -> Producer<P, S> {
    let bufferSize = bufferSize.bufferSize(self)
    let producer = Producer<P, S>(bufferSize: bufferSize)
    self.attach(producer: producer, executor: executor, cancellationToken: cancellationToken, onValue: onValue)
    return producer
  }

  /// **internal use only**
  func attach<P, S>(producer: Producer<P, S>,
              executor: Executor,
              cancellationToken: CancellationToken?,
              onValue: @escaping (Value, Producer<P, S>) throws -> Void)
  {
    let handler = self.makeHandler(executor: executor) {
      [weak producer] (value) in
      guard let producer = producer else { return }
      do { try onValue(value, producer) }
      catch { producer.fail(with: error) }
    }

    producer.insertHandlerToReleasePool(handler)
    cancellationToken?.add(cancellable: producer)
  }

  /// **internal use only**
  func makeProducer<P, S, C: ExecutionContext>(context: C,
                    executor: Executor?,
                    cancellationToken: CancellationToken?,
                    bufferSize: DerivedChannelBufferSize,
                    onValue: @escaping (C, Value, Producer<P, S>) throws -> Void
    ) -> Producer<P, S> {
    let bufferSize = bufferSize.bufferSize(self)
    let producer = Producer<P, S>(bufferSize: bufferSize)
    self.attach(producer: producer, context: context, executor: executor, cancellationToken: cancellationToken, onValue: onValue)
    return producer
  }

  /// **internal use only**
  func attach<P, S, C: ExecutionContext>(producer: Producer<P, S>,
              context: C,
              executor: Executor?,
              cancellationToken: CancellationToken?,
              onValue: @escaping (C, Value, Producer<P, S>) throws -> Void)
  {
    let executor_ = executor ?? context.executor
    self.attach(producer: producer, executor: executor_, cancellationToken: cancellationToken)
    {
      [weak context] (value, producer) in
      guard let context = context else { return }
      try onValue(context, value, producer)
    }

    context.addDependent(finite: producer)
  }
}

// MARK: - whole channel transformations
public extension Channel {

  /// Applies transformation to the whole channel. `mapPeriodic` methods
  /// are more convenient if you want to transform periodics values only.
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply
  ///   - strongContext: context restored from weak reference to specified context
  ///   - value: `ChannelValue` to transform. May be either periodic or final
  /// - Returns: transformed channel
  func map<P, S, C: ExecutionContext>(context: C,
           executor: Executor? = nil,
           cancellationToken: CancellationToken? = nil,
           bufferSize: DerivedChannelBufferSize = .default,
           transform: @escaping (_ strongContext: C, _ value: Value) throws -> ChannelValue<P, S>
    ) -> Channel<P, S> {
    return self.makeProducer(context: context,
                             executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (context, value, producer) in
      let transformedValue = try transform(context, value)
      producer.apply(transformedValue)
    }
  }

  /// Applies transformation to the whole channel. `mapPeriodic` methods
  /// are more convenient if you want to transform periodics values only.
  ///
  /// - Parameters:
  ///   - executor: to execute transform on
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply
  ///   - value: `ChannelValue` to transform. May be either periodic or final
  /// - Returns: transformed channel
  func map<P, S>(executor: Executor = .primary,
           cancellationToken: CancellationToken? = nil,
           bufferSize: DerivedChannelBufferSize = .default,
           transform: @escaping (_ value: Value) throws -> ChannelValue<P, S>
    ) -> Channel<P, S> {
    return self.makeProducer(executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (value, producer) in
      let transformedValue = try transform(value)
      producer.apply(transformedValue)
    }
  }
}

// MARK: - periodics only transformations

public extension Channel {

  /// Applies transformation to periodic values of the channel.
  /// `map` methods are more convenient if you want to transform
  /// both periodics and final value
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use. Keep default value
  ///     of the argument unless you need an extended cancellation options
  ///     of the returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func mapPeriodic<P, C: ExecutionContext>(context: C,
                   executor: Executor? = nil,
                   cancellationToken: CancellationToken? = nil,
                   bufferSize: DerivedChannelBufferSize = .default,
                   transform: @escaping (_ strongContext: C, _ periodicValue: PeriodicValue) throws -> P
    ) -> Channel<P, FinalValue> {
    return self.makeProducer(context: context,
                             executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
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

  /// Applies transformation to periodic values of the channel.
  /// `map` methods are more convenient if you want to transform
  /// both periodics and final value
  ///
  /// - Parameters:
  ///   - executor: to execute transform on
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func mapPeriodic<P>(executor: Executor = .primary,
                   cancellationToken: CancellationToken? = nil,
                   bufferSize: DerivedChannelBufferSize = .default,
                   transform: @escaping (_ periodicValue: PeriodicValue) throws -> P
    ) -> Channel<P, FinalValue> {
    return self.makeProducer(executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
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
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply. Nil returned from transform will not produce periodic value
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func flatMapPeriodic<P, C: ExecutionContext>(context: C,
                       executor: Executor? = nil,
                       cancellationToken: CancellationToken? = nil,
                       bufferSize: DerivedChannelBufferSize = .default,
                       transform: @escaping (_ strongContext: C, _ periodicValue: PeriodicValue) throws -> P?
    ) -> Channel<P, FinalValue> {
    return self.makeProducer(context: context,
                             executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
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
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply. Nil returned from transform will not produce periodic value
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func flatMapPeriodic<P>(executor: Executor = .primary,
                       cancellationToken: CancellationToken? = nil,
                       bufferSize: DerivedChannelBufferSize = .default,
                       transform: @escaping (_ periodicValue: PeriodicValue) throws -> P?
    ) -> Channel<P, FinalValue> {
    return self.makeProducer(executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
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
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need
  ///     to override an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply. Sequence returned from transform
  ///     will be treated as multiple period values
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func flatMapPeriodic<PS: Sequence, C: ExecutionContext>(context: C,
                       executor: Executor? = nil,
                       cancellationToken: CancellationToken? = nil,
                       bufferSize: DerivedChannelBufferSize = .default,
                       transform: @escaping (_ strongContext: C, _ periodicValue: PeriodicValue) throws -> PS
    ) -> Channel<PS.Iterator.Element, FinalValue> {
    return self.makeProducer(context: context,
                             executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
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
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply. Sequence returned from transform
  ///     will be treated as multiple period values
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: transformed channel
  func flatMapPeriodic<PS: Sequence>(executor: Executor = .primary,
                       cancellationToken: CancellationToken? = nil,
                       bufferSize: DerivedChannelBufferSize = .default,
                       transform: @escaping (_ periodicValue: PeriodicValue) throws -> PS
    ) -> Channel<PS.Iterator.Element, FinalValue> {
    return self.makeProducer(executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
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

// MARK: convenient transformations

public extension Channel {

  /// Filters periodic values of the channel
  ///
  ///   - context: `ExectionContext` to apply predicate in
  ///   - executor: override of `ExecutionContext`s executor. Keep default value of the argument unless you need to override an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use. Keep default value of the argument unless you need an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel. Keep default value of the argument unless you need an extended buffering options of returned channel
  ///   - predicate: to apply
  ///   - strongContext: context restored from weak reference to specified context
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: filtered transform
  func filterPeriodic<C: ExecutionContext>(context: C,
                      executor: Executor? = nil,
                      cancellationToken: CancellationToken? = nil,
                      bufferSize: DerivedChannelBufferSize = .default,
                      predicate: @escaping (_ strongContext: C, _ periodicValue: PeriodicValue) throws -> Bool
    ) -> Channel<PeriodicValue, FinalValue> {
    return self.makeProducer(context: context,
                             executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
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
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - predicate: to apply
  ///   - periodicValue: `PeriodicValue` to transform
  /// - Returns: filtered transform
  func filterPeriodic(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    predicate: @escaping (_ periodicValue: PeriodicValue) throws -> Bool
    ) -> Channel<PeriodicValue, FinalValue> {
    return self.makeProducer(executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
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
}
