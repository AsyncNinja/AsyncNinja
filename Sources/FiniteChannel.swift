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

public class FiniteChannel<T, U> : Periodic, Finite {
  public typealias PeriodicValue = T
  public typealias FinalValue = U
  public typealias Value = FiniteChannelValue<PeriodicValue, FinalValue>
  public typealias Handler = FiniteChannelHandler<PeriodicValue, FinalValue>
  public typealias PeriodicHandler = Handler
  public typealias FinalHandler = Handler

  public var finalValue: FinalValue? {
    /* abstact */
    fatalError()
  }

  init() { }

  final public func makeFinalHandler(executor: Executor,
                                     block: @escaping (FinalValue) -> Void) -> Handler? {
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

public enum FiniteChannelValue<T, U> {
  public typealias PeriodicValue = T
  public typealias FinalValue = U

  case periodic(PeriodicValue)
  case final(FinalValue)
}

/// **internal use only**
final public class FiniteChannelHandler<T, U> {
  public typealias PeriodicValue = T
  public typealias FinalValue = U
  public typealias Value = FiniteChannelValue<PeriodicValue, FinalValue>

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

// this code duplication from Channel is a thing because parametrized associatedtype is not yet a thing.
extension FiniteChannel {
  func makeFiniteProducer<T>(executor: Executor, cancellationToken: CancellationToken?,
                          onPeriodic: @escaping (PeriodicValue, FiniteProducer<T, Fallible<FinalValue>>) throws -> Void) -> FiniteProducer<T, Fallible<FinalValue>> {
    let producer = FiniteProducer<T, Fallible<FinalValue>>()
    let handler = self.makeHandler(executor: executor) { [weak producer] (value) in
      guard let producer = producer else { return }
      switch value {
      case .periodic(let periodicValue):
        do { try onPeriodic(periodicValue, producer) }
        catch { producer.fail(with: error) }
      case .final(let final):
        producer.succeed(with: final)
      }
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
                          onPeriodic: @escaping (U, PeriodicValue, FiniteProducer<T, Fallible<FinalValue>>) throws -> Void) -> FiniteProducer<T, Fallible<FinalValue>> {
    let producer: FiniteProducer<T, Fallible<FinalValue>> = self.makeFiniteProducer(executor: executor ?? context.executor, cancellationToken: cancellationToken) {
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
                         onPeriodic: @escaping (PeriodicValue, (T) throws -> Void) throws -> Void) -> FiniteChannel<T, Fallible<FinalValue>> {
    return self.makeFiniteProducer(executor: executor, cancellationToken: cancellationToken) { (periodicValue: PeriodicValue, producer: FiniteProducer<T, Fallible<FinalValue>>) -> Void in
      try onPeriodic(periodicValue) { producer.send($0) }
    }
  }

  func makeFiniteChannel<T, U: ExecutionContext>(context: U, executor: Executor?, cancellationToken: CancellationToken?,
                         onPeriodic: @escaping (U, PeriodicValue, (T) throws -> Void) throws -> Void) -> FiniteChannel<T, Fallible<FinalValue>> {
    return self.makeFiniteProducer(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context, periodicValue, producer) -> Void in
      try onPeriodic(context, periodicValue) { producer.send($0) }
    }
  }
}

public extension FiniteChannel {
  func mapPeriodic<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                   transform: @escaping (U, PeriodicValue) throws -> T) -> FiniteChannel<T, Fallible<FinalValue>> {
    return self.makeFiniteChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: Channel.PeriodicValue, send: (T) throws -> Void) in
      let transformedValue = try transform(context, periodicValue)
      try send(transformedValue)
    }
  }

  func flatMapPeriodic<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                       transform: @escaping (U, PeriodicValue) throws -> T?) -> FiniteChannel<T, Fallible<FinalValue>> {
    return self.makeFiniteChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: Channel.PeriodicValue, send: (T) throws -> Void) in
      if let transformedValue = try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }

  func flatMapPeriodic<S: Sequence, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                       transform: @escaping (U, PeriodicValue) throws -> S) -> FiniteChannel<S.Iterator.Element, Fallible<FinalValue>> {
    return self.makeFiniteChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: Channel.PeriodicValue, send: (S.Iterator.Element) throws -> Void) in
      for transformedValue in try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }
}

extension FiniteChannel where U : _Fallible {
  func makeFiniteProducer<T>(executor: Executor, cancellationToken: CancellationToken?,
                          onPeriodic: @escaping (PeriodicValue, FiniteProducer<T, FinalValue>) throws -> Void) -> FiniteProducer<T, FinalValue> {
    let producer = FiniteProducer<T, FinalValue>()
    let handler = self.makeHandler(executor: executor) { [weak producer] (value) in
      guard let producer = producer else { return }
      switch value {
      case .periodic(let periodicValue):
        do { try onPeriodic(periodicValue, producer) }
        catch { producer.fail(with: error) }
      case .final(let final):
        producer.complete(with: final)
      }
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
                          onPeriodic: @escaping (U, PeriodicValue, FiniteProducer<T, FinalValue>) throws -> Void) -> FiniteProducer<T, FinalValue> {
    let producer: FiniteProducer<T, FinalValue> = self.makeFiniteProducer(executor: executor ?? context.executor, cancellationToken: cancellationToken) {
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
                         onPeriodic: @escaping (PeriodicValue, (T) throws -> Void) throws -> Void) -> FiniteChannel<T, FinalValue> {
    return self.makeFiniteProducer(executor: executor, cancellationToken: cancellationToken) { (periodicValue: PeriodicValue, producer: FiniteProducer<T, FinalValue>) -> Void in
      try onPeriodic(periodicValue) { producer.send($0) }
    }
  }

  func makeFiniteChannel<T, U: ExecutionContext>(context: U, executor: Executor?, cancellationToken: CancellationToken?,
                         onPeriodic: @escaping (U, PeriodicValue, (T) throws -> Void) throws -> Void) -> FiniteChannel<T, FinalValue> {
    return self.makeFiniteProducer(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context, periodicValue, producer) -> Void in
      try onPeriodic(context, periodicValue) { producer.send($0) }
    }
  }
}

public extension FiniteChannel where U : _Fallible {
  func mapPeriodic<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                   transform: @escaping (U, PeriodicValue) throws -> T) -> FiniteChannel<T, FinalValue> {
    return self.makeFiniteChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: Channel.PeriodicValue, send: (T) throws -> Void) in
      let transformedValue = try transform(context, periodicValue)
      try send(transformedValue)
    }
  }

  func flatMapPeriodic<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                       transform: @escaping (U, PeriodicValue) throws -> T?) -> FiniteChannel<T, FinalValue> {
    return self.makeFiniteChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: Channel.PeriodicValue, send: (T) throws -> Void) in
      if let transformedValue = try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }

  func flatMapPeriodic<S: Sequence, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                       transform: @escaping (U, PeriodicValue) throws -> S) -> FiniteChannel<S.Iterator.Element, FinalValue> {
    return self.makeFiniteChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: Channel.PeriodicValue, send: (S.Iterator.Element) throws -> Void) in
      for transformedValue in try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }
}
