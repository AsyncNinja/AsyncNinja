//
//  Copyright (c) 2016-2020 Anton Mironov, Sergiy Vynnychenko
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
    
    return AsyncNinja.producer(
      executor: executor ?? self.executor,
      cancellationToken: cancellationToken,
      bufferSize: bufferSize
    ) { [weak self] (producer: Producer<Update, Success>) in
      guard let _self = self else { return }
      _self.addDependent(completable: producer)
      try block(_self, producer)
    }
  }
}
