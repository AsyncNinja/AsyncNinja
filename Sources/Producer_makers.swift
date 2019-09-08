//
//  Producer_makers.swift
//  AsyncNinja
//
//  Created by Sergiy Vynnychenko on 3/25/19.
//

import Dispatch

// MARK: - producer()
/// Convenience constructor of Producer
/// Gives an access to an underlying Producer to a provided block
public func producer<Update, Success>(
  executor: Executor = .main,
  cancellationToken: CancellationToken? = nil,
  bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
  block: @escaping (_ producer: Producer<Update, Success>) throws -> Void
  ) -> Producer<Update, Success> {
  // TEST: ChannelMakersTests.testMakeChannelWithProducerProvidingBlock
  
  let producer = Producer<Update, Success>(bufferSize: bufferSize)
  cancellationToken?.add(cancellable: producer)
  executor.schedule { originalExecutor in
    do {
      try block(producer)
    } catch {
      producer.fail(error, from: originalExecutor)
    }
  }
  return producer
}

public extension ExecutionContext {
  // MARK: - producer()
  /// Convenience constructor of Producer
  /// Gives an access to an underlying Producer to a provided block
  func producer<Update, Success>(
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
    block: @escaping (_ context: Self, _ strongProducer: Producer<Update, Success>) throws -> Void
    ) -> Producer<Update, Success> {
    
    return AsyncNinja.producer(executor: executor ?? self.executor,
                               cancellationToken: cancellationToken,
                               bufferSize: bufferSize
    ) { [weak self] (producer: Producer<Update, Success>) in
      guard let _self = self else { return }
      _self.addDependent(completable: producer)
      try block(_self, producer)
    }
  }
}
