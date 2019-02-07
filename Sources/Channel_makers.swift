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

/// Convenience constructor of Channel. Encapsulates cancellation and producer creation.
public func channel<Update, Success>(
  executor: Executor = .primary,
  cancellationToken: CancellationToken? = nil,
  bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
  block: @escaping (_ update: @escaping (Update) -> Void) throws -> Success
  ) -> Channel<Update, Success> {
  // TEST: ChannelMakersTests.testMakeChannel

  let producer = Producer<Update, Success>(bufferSize: bufferSize)
  cancellationToken?.add(cancellable: producer)
  executor.execute(
    from: nil
  ) { [weak producer] (originalExecutor) in
    let fallibleCompletion = fallible {
      try block { producer?.update($0, from: originalExecutor) }
    }
    producer?.complete(fallibleCompletion, from: originalExecutor)
  }
  return producer
}

func _producer<Update, Success>(
  cancellationToken: CancellationToken?,
  bufferSize: Int,
  block: (@escaping (Update) -> Void, @escaping (Fallible<Success>) -> Void) -> Void
  ) -> Producer<Update, Success> {

  let producer = Producer<Update, Success>(bufferSize: bufferSize)
  cancellationToken?.add(cancellable: producer)

  let weakProducerBox = WeakBox(producer)
  func update(_ update: Update) {
    weakProducerBox.value?.update(update)
  }

  func complete(_ completion: Fallible<Success>) {
    weakProducerBox.value?.complete(completion)
  }

  block(update, complete)
  return producer
}

/// Convenience constructor of Channel. Encapsulates cancellation and producer creation.
public func channel<Update, Success>(
  cancellationToken: CancellationToken? = nil,
  bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
  block: (@escaping (Update) -> Void, @escaping (Fallible<Success>) -> Void) -> Void
  ) -> Channel<Update, Success> {

  // TEST: ChannelMakersTests.testMakeChannel2
  return _producer(cancellationToken: cancellationToken,
                   bufferSize: bufferSize,
                   block: block)
}

/// Convenience constructor of Channel. Encapsulates cancellation and producer creation.
public func channel<C: ExecutionContext, Update, Success>(
  context: C,
  cancellationToken: CancellationToken? = nil,
  bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
  _ block: (C, @escaping (Update) -> Void, @escaping (Fallible<Success>) -> Void) -> Void
  ) -> Channel<Update, Success> {

  let producer = _producer(cancellationToken: cancellationToken,
                           bufferSize: bufferSize
  ) { (update, complete) in
    block(context, update, complete)
  }
  context.addDependent(cancellable: producer)
  return producer
}

/// Convenience contextual constructor of Channel. Encapsulates cancellation and producer creation.
public func channel<C: ExecutionContext, Update, Success>(
  context: C,
  executor: Executor? = nil,
  cancellationToken: CancellationToken? = nil,
  bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
  block: @escaping (_ strongContext: C, _ update: @escaping (Update) -> Void) throws -> Success
  ) -> Channel<Update, Success> {
  // TEST: ChannelMakersTests.testMakeChannelContextual

  let producer = Producer<Update, Success>(bufferSize: bufferSize)
  context.addDependent(completable: producer)
  cancellationToken?.add(cancellable: producer)
  (executor ?? context.executor).execute(
    from: nil
  ) { [weak context, weak producer] (originalExecutor) in
    guard case .some = producer else { return }
    guard let context = context else {
      producer?.cancelBecauseOfDeallocatedContext(from: originalExecutor)
      return
    }
    let fallibleCompleting = fallible {
      try block(context) {
        producer?.update($0, from: originalExecutor)
      }
    }
    producer?.complete(fallibleCompleting, from: originalExecutor)
  }
  return producer
}

/// Convenience function constructs completed Channel with specified updates and completion
public func channel<C: Collection, Success>(
  updates: C,
  completion: Fallible<Success>
  ) -> Channel<C.Iterator.Element, Success> {
  // TEST: ChannelMakersTests.testCompletedWithFunc

  let producer = Producer<C.Iterator.Element, Success>(bufferedUpdates: updates)
  producer.complete(completion, from: nil)
  return producer
}

/// Convenience function constructs succeded Channel with specified updates and success
public func channel<C: Collection, Success>(
  updates: C,
  success: Success
  ) -> Channel<C.Iterator.Element, Success> {
  // TEST: ChannelMakersTests.testSucceededWithFunc

  return channel(updates: updates, completion: .success(success))
}

/// Convenience function constructs failed Channel with specified updates and failure
public func channel<C: Collection, Success>(
  updates: C,
  failure: Swift.Error
  ) -> Channel<C.Iterator.Element, Success> {
  // TEST: ChannelMakersTests.testFailedWithFunc

  return channel(updates: updates, completion: .failure(failure))
}

// MARK: -
/// Convenience constructor of Channel
/// Gives an access to an underlying Producer to a provided block
public func channel<Update, Success>(
  executor: Executor = .immediate,
  cancellationToken: CancellationToken? = nil,
  bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
  block: @escaping (_ producer: Producer<Update, Success>) throws -> Void
  ) -> Channel<Update, Success> {
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

/// Convenience constructor of Channel
/// Gives an access to an underlying Producer to a provided block
public func channel<C: ExecutionContext, Update, Success>(
  context: C,
  executor: Executor? = nil,
  cancellationToken: CancellationToken? = nil,
  bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
  block: @escaping (_ context: C, _ strongProducer: Producer<Update, Success>) throws -> Void
  ) -> Channel<Update, Success> {
  // TEST: ChannelMakersTests.testMakeChannelWithProducerProvidingBlockWithDeadContext

  return channel(executor: executor ?? context.executor,
                 cancellationToken: cancellationToken,
                 bufferSize: bufferSize
  ) { (producer: Producer<Update, Success>) in
    context.addDependent(completable: producer)
    try block(context, producer)
  }
}

// MARK: -

/// Convenience shortcuts for making completed channel
public extension Channel {

  /// Makes completed channel
  static func completed(_ completion: Fallible<Success>) -> Channel<Update, Success> {
    // TEST: ChannelMakersTests.testCompletedWithStatic

    return channel(updates: [], completion: completion)
  }

  /// Makes succeeded channel
  static func succeeded(_ success: Success) -> Channel<Update, Success> {
    // TEST: ChannelMakersTests.testSucceededWithStatic

    return .completed(.success(success))
  }

  /// Makes succeeded channel
  static func just(_ success: Success) -> Channel<Update, Success> {
    // TEST: ChannelMakersTests.testSucceededWithJust

    return .completed(.success(success))
  }

  /// Makes failed channel
  static func failed(_ failure: Swift.Error) -> Channel<Update, Success> {
    // TEST: ChannelMakersTests.testFailedWithStatic

    return .completed(.failure(failure))
  }

  /// Makes cancelled (failed with AsyncNinjaError.cancelled) channel
  static var cancelled: Channel<Update, Success> {
    // TEST: ChannelMakersTests.testCancelled

    return .failed(AsyncNinjaError.cancelled)
  }
}
