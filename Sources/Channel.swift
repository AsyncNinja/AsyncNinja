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
  func makeProducer<T>(executor: Executor, cancellationToken: CancellationToken?,
                          onPeriodic: @escaping (PeriodicValue, Producer<T, FinalValue>) throws -> Void) -> Producer<T, FinalValue> {
    let producer = Producer<T, FinalValue>()
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

  func makeProducer<T, U: ExecutionContext>(context: U, executor: Executor?, cancellationToken: CancellationToken?,
                          onPeriodic: @escaping (U, PeriodicValue, Producer<T, FinalValue>) throws -> Void) -> Producer<T, FinalValue> {
    let producer: Producer<T, FinalValue> = self.makeProducer(executor: executor ?? context.executor, cancellationToken: cancellationToken) {
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
                         onPeriodic: @escaping (PeriodicValue, (T) throws -> Void) throws -> Void) -> Channel<T, FinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken) { (periodicValue: PeriodicValue, producer: Producer<T, FinalValue>) -> Void in
      try onPeriodic(periodicValue) { producer.send($0) }
    }
  }

  func makeChannel<T, U: ExecutionContext>(context: U, executor: Executor?, cancellationToken: CancellationToken?,
                         onPeriodic: @escaping (U, PeriodicValue, (T) throws -> Void) throws -> Void) -> Channel<T, FinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context, periodicValue, producer) -> Void in
      try onPeriodic(context, periodicValue) { producer.send($0) }
    }
  }
}

public extension Channel {
  func mapPeriodic<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                   transform: @escaping (U, PeriodicValue) throws -> T) -> Channel<T, FinalValue> {
    return self.makeChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: PeriodicValue, send: (T) throws -> Void) in
      let transformedValue = try transform(context, periodicValue)
      try send(transformedValue)
    }
  }

  func flatMapPeriodic<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                       transform: @escaping (U, PeriodicValue) throws -> T?) -> Channel<T, FinalValue> {
    return self.makeChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: PeriodicValue, send: (T) throws -> Void) in
      if let transformedValue = try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }

  func flatMapPeriodic<S: Sequence, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
                       transform: @escaping (U, PeriodicValue) throws -> S) -> Channel<S.Iterator.Element, FinalValue> {
    return self.makeChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: PeriodicValue, send: (S.Iterator.Element) throws -> Void) in
      for transformedValue in try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }
}

extension Channel where FinalValue : _Fallible {
  func makeProducer<T>(executor: Executor, cancellationToken: CancellationToken?,
                          onPeriodic: @escaping (PeriodicValue, Producer<T, FinalValue>) throws -> Void) -> Producer<T, FinalValue> {
    let producer = Producer<T, FinalValue>()
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

  func makeProducer<T, U: ExecutionContext>(context: U, executor: Executor?, cancellationToken: CancellationToken?,
                          onPeriodic: @escaping (U, PeriodicValue, Producer<T, FinalValue>) throws -> Void) -> Producer<T, FinalValue> {
    let producer: Producer<T, FinalValue> = self.makeProducer(executor: executor ?? context.executor, cancellationToken: cancellationToken) {
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
                         onPeriodic: @escaping (PeriodicValue, (T) throws -> Void) throws -> Void) -> Channel<T, FinalValue> {
    return self.makeProducer(executor: executor, cancellationToken: cancellationToken) { (periodicValue: PeriodicValue, producer: Producer<T, FinalValue>) -> Void in
      try onPeriodic(periodicValue) { producer.send($0) }
    }
  }

  func makeChannel<T, U: ExecutionContext>(context: U, executor: Executor?, cancellationToken: CancellationToken?,
                         onPeriodic: @escaping (U, PeriodicValue, (T) throws -> Void) throws -> Void) -> Channel<T, FinalValue> {
    return self.makeProducer(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context, periodicValue, producer) -> Void in
      try onPeriodic(context, periodicValue) { producer.send($0) }
    }
  }
}

public extension Channel where FinalValue : _Fallible {
  func map<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
           transform: @escaping (U, PeriodicValue) throws -> T) -> Channel<T, FinalValue> {
    return self.makeChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: PeriodicValue, send: (T) throws -> Void) in
      let transformedValue = try transform(context, periodicValue)
      try send(transformedValue)
    }
  }

  func flatMap<T, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
               transform: @escaping (U, PeriodicValue) throws -> T?) -> Channel<T, FinalValue> {
    return self.makeChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: PeriodicValue, send: (T) throws -> Void) in
      if let transformedValue = try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }

  func flatMap<S: Sequence, U: ExecutionContext>(context: U, executor: Executor? = nil, cancellationToken: CancellationToken? = nil,
               transform: @escaping (U, PeriodicValue) throws -> S) -> Channel<S.Iterator.Element, FinalValue> {
    return self.makeChannel(context: context, executor: executor, cancellationToken: cancellationToken) {
      (context: U, periodicValue: PeriodicValue, send: (S.Iterator.Element) throws -> Void) in
      for transformedValue in try transform(context, periodicValue) {
        try send(transformedValue)
      }
    }
  }
}
