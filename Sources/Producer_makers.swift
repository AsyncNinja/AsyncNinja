//
//  Producer_makers.swift
//  AsyncNinja
//
//  Created by Loki on 3/25/19.
//

import Dispatch

// MARK: -
/// Convenience constructor of Producer
/// Gives an access to an underlying Producer to a provided block
public func producer<Update, Success>(
    executor: Executor = .immediate,
    cancellationToken: CancellationToken? = nil,
    bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
    block: @escaping (_ producer: Producer<Update, Success>) throws -> Void
    ) -> Producer<Update, Success> {
    // TEST: ChannelMakersTests.testMakeChannelWithProducerProvidingBlock
    
    let producer = Producer<Update, Success>(bufferSize: bufferSize)
    cancellationToken?.add(cancellable: producer)
    executor.execute(from: nil) { (originalExecutor) in
        do {
            try block(producer)
        } catch {
            producer.fail(error, from: originalExecutor)
        }
    }
    return producer
}

/// Convenience constructor of Producer
/// Gives an access to an underlying Producer to a provided block
public func producer<C: ExecutionContext, Update, Success>(
    context: C,
    executor: Executor? = nil,
    cancellationToken: CancellationToken? = nil,
    bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
    block: @escaping (_ context: C, _ strongProducer: Producer<Update, Success>) throws -> Void
    ) -> Producer<Update, Success> {
    // TEST: ChannelMakersTests.testMakeChannelWithProducerProvidingBlockWithDeadContext
    
    return producer(executor: executor ?? context.executor,
                   cancellationToken: cancellationToken,
                   bufferSize: bufferSize
    ) { (producer: Producer<Update, Success>) in
        context.addDependent(completable: producer)
        try block(context, producer)
    }
}
