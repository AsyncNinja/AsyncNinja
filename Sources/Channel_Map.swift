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
  func makeProducer<P, S>(
    executor: Executor,
    cancellationToken: CancellationToken?,
    bufferSize: DerivedChannelBufferSize,
    _ onValue: @escaping (Value, Producer<P, S>) throws -> Void
    ) -> Producer<P, S> {
    let bufferSize = bufferSize.bufferSize(self)
    let producer = Producer<P, S>(bufferSize: bufferSize)
    self.attach(producer: producer, executor: executor,
                cancellationToken: cancellationToken, onValue)
    return producer
  }

  /// **internal use only**
  func attach<P, S>(
    producer: Producer<P, S>,
    executor: Executor,
    cancellationToken: CancellationToken?,
    _ onValue: @escaping (Value, Producer<P, S>) throws -> Void)
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
  func makeProducer<P, S, C: ExecutionContext>(
    context: C,
    executor: Executor?,
    cancellationToken: CancellationToken?,
    bufferSize: DerivedChannelBufferSize,
    _ onValue: @escaping (C, Value, Producer<P, S>) throws -> Void
    ) -> Producer<P, S> {
    let bufferSize = bufferSize.bufferSize(self)
    let producer = Producer<P, S>(bufferSize: bufferSize)
    self.attach(producer: producer, context: context, executor: executor,
                cancellationToken: cancellationToken, onValue)
    return producer
  }

  /// **internal use only**
  func attach<P, S, C: ExecutionContext>(
    producer: Producer<P, S>,
    context: C,
    executor: Executor?,
    cancellationToken: CancellationToken?,
    _ onValue: @escaping (C, Value, Producer<P, S>) throws -> Void)
  {
    let executor_ = executor ?? context.executor
    self.attach(producer: producer, executor: executor_, cancellationToken: cancellationToken)
    {
      [weak context] (value, producer) in
      guard let context = context else { return }
      try onValue(context, value, producer)
    }
    
    context.addDependent(completable: producer)
  }
}

// MARK: - whole channel transformations
public extension Channel {

  /// Applies transformation to the whole channel. `mapUpdate` methods
  /// are more convenient if you want to transform updates values only.
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
  ///   - value: `ChannelValue` to transform. May be either update or completion
  /// - Returns: transformed channel
  func map<P, S, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ strongContext: C, _ value: Value) throws -> ChannelValue<P, S>
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

  /// Applies transformation to the whole channel. `mapUpdate` methods
  /// are more convenient if you want to transform updates values only.
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
  ///   - value: `ChannelValue` to transform. May be either update or completion
  /// - Returns: transformed channel
  func map<P, S>(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ value: Value) throws -> ChannelValue<P, S>
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

// MARK: - updates only transformations

public extension Channel {

  /// Applies transformation to update values of the channel.
  /// `map` methods are more convenient if you want to transform
  /// both updates and completion
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
  ///   - update: `Update` to transform
  /// - Returns: transformed channel
  func mapUpdate<P, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ strongContext: C, _ update: Update) throws -> P
    ) -> Channel<P, Success> {
    return self.makeProducer(context: context,
                             executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (context, value, producer) in
      switch value {
      case .update(let update):
        let transformedValue = try transform(context, update)
        producer.send(transformedValue)
      case .completion(let completion):
        producer.complete(with: completion)
      }
    }
  }

  /// Applies transformation to update values of the channel.
  /// `map` methods are more convenient if you want to transform
  /// both updates and completion
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
  ///   - update: `Update` to transform
  /// - Returns: transformed channel
  func mapUpdate<P>(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ update: Update) throws -> P
    ) -> Channel<P, Success> {

    // Test: Channel_MapTests.testMapUpdate

    return self.makeProducer(executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (value, producer) in
      switch value {
      case .update(let update):
        let transformedValue = try transform(update)
        producer.send(transformedValue)
      case .completion(let completion):
        producer.complete(with: completion)
      }
    }
  }
}

// MARK: - updates only flattening transformations

public extension Channel {

  /// Applies transformation to update values of the channel.
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
  ///   - transform: to apply. Nil returned from transform will not produce update value
  ///   - strongContext: context restored from weak reference to specified context
  ///   - update: `Update` to transform
  /// - Returns: transformed channel
  func flatMapUpdate<P, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ strongContext: C, _ update: Update) throws -> P?
    ) -> Channel<P, Success> {
    return self.makeProducer(context: context,
                             executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (context, value, producer) in
      switch value {
      case .update(let update):
        if let transformedValue = try transform(context, update) {
          producer.send(transformedValue)
        }
      case .completion(let completion):
        producer.complete(with: completion)
      }
    }
  }

  /// Applies transformation to update values of the channel.
  ///
  /// - Parameters:
  ///   - executor: to execute transform on
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - transform: to apply. Nil returned from transform will not produce update value
  ///   - update: `Update` to transform
  /// - Returns: transformed channel
  func flatMapUpdate<P>(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ update: Update) throws -> P?
    ) -> Channel<P, Success> {
    return self.makeProducer(executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (value, producer) in
      switch value {
      case .update(let update):
        if let transformedValue = try transform(update) {
          producer.send(transformedValue)
        }
      case .completion(let completion):
        producer.complete(with: completion)
      }
    }
  }

  /// Applies transformation to update values of the channel.
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
  ///   - update: `Update` to transform
  /// - Returns: transformed channel
  func flatMapUpdate<PS: Sequence, C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ strongContext: C, _ update: Update) throws -> PS
    ) -> Channel<PS.Iterator.Element, Success> {
    return self.makeProducer(context: context,
                             executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (context, value, producer) in
      switch value {
      case .update(let update):
        try transform(context, update).forEach(producer.send)
      case .completion(let completion):
        producer.complete(with: completion)
      }
    }
  }

  /// Applies transformation to update values of the channel.
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
  ///   - update: `Update` to transform
  /// - Returns: transformed channel
  func flatMapUpdate<PS: Sequence>(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ transform: @escaping (_ update: Update) throws -> PS
    ) -> Channel<PS.Iterator.Element, Success> {
    return self.makeProducer(executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (value, producer) in
      switch value {
      case .update(let update):
        try transform(update).forEach(producer.send)
      case .completion(let completion):
        producer.complete(with: completion)
      }
    }
  }
}

// MARK: convenient transformations

public extension Channel {

  /// Filters update values of the channel
  ///
  ///   - context: `ExectionContext` to apply predicate in
  ///   - executor: override of `ExecutionContext`s executor. Keep default value of the argument unless you need to override an executor provided by the context
  ///   - cancellationToken: `CancellationToken` to use. Keep default value of the argument unless you need an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel. Keep default value of the argument unless you need an extended buffering options of returned channel
  ///   - predicate: to apply
  ///   - strongContext: context restored from weak reference to specified context
  ///   - update: `Update` to transform
  /// - Returns: filtered transform
  func filterUpdate<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ predicate: @escaping (_ strongContext: C, _ update: Update) throws -> Bool
    ) -> Channel<Update, Success> {
    return self.makeProducer(context: context,
                             executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (context, value, producer) in
      switch value {
      case .update(let update):
        do {
          if try predicate(context, update) {
            producer.send(update)
          }
        } catch { producer.fail(with: error) }
      case .completion(let completion):
        producer.complete(with: completion)
      }
    }
  }

  /// Filters update values of the channel
  ///
  ///   - executor: to execute transform on
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - predicate: to apply
  ///   - update: `Update` to transform
  /// - Returns: filtered transform
  func filterUpdate(
    executor: Executor = .primary,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    _ predicate: @escaping (_ update: Update) throws -> Bool
    ) -> Channel<Update, Success> {

    // Test: Channel_MapTests.testFilterUpdate

    return self.makeProducer(executor: executor,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (value, producer) in
      switch value {
      case .update(let update):
        do {
          if try predicate(update) {
            producer.send(update)
          }
        } catch { producer.fail(with: error) }
      case .completion(let completion):
        producer.complete(with: completion)
      }
    }
  }
}
