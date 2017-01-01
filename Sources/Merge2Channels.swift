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

/// Merges channels with completely unrelated types into one
public func merge<PeriodicValueA, PeriodicValueB, SuccessValueA, SuccessValueB>(
  _ channelA: Channel<PeriodicValueA, SuccessValueA>,
  _ channelB: Channel<PeriodicValueB, SuccessValueB>,
  cancellationToken: CancellationToken? = nil,
  bufferSize: DerivedChannelBufferSize = .default
  ) -> Channel<Either<PeriodicValueA, PeriodicValueB>, (SuccessValueA, SuccessValueB)> {
  let bufferSize_ = bufferSize.bufferSize(channelA, channelB)
  let producer = Producer<Either<PeriodicValueA, PeriodicValueB>, (SuccessValueA, SuccessValueB)>(bufferSize: bufferSize_)

  var locking = makeLocking()
  var successA: SuccessValueA?
  var successB: SuccessValueB?

  func makeHandlerBlock<PeriodicValue, FinalValue>(
    periodicHandler: @escaping (PeriodicValue) -> Void,
    successHandler: @escaping (FinalValue) -> Void
    ) -> (ChannelValue<PeriodicValue, FinalValue>) -> Void {
    return {
      [weak producer] (value) in
      switch value {
      case let .periodic(periodic):
        periodicHandler(periodic)
      case let .final(.failure(error)):
        producer?.fail(with: error)
      case let .final(.success(localSuccess)):
        locking.lock()
        defer { locking.unlock() }
        successHandler(localSuccess)
        if let localSuccessA = successA, let localSuccessB = successB {
          producer?.succeed(with: (localSuccessA, localSuccessB))
        }
      }
    }
  }

  let handlerBlockA = makeHandlerBlock(periodicHandler: { [weak producer] in producer?.send(.left($0)) },
                                       successHandler: { (success: SuccessValueA) in successA = success })
  if let handler = channelA.makeHandler(executor: .immediate, block: handlerBlockA) {
    producer.insertToReleasePool(handler)
  }

  let handlerBlockB = makeHandlerBlock(periodicHandler: { [weak producer] in producer?.send(.right($0)) },
                                       successHandler: { (success: SuccessValueB) in successB = success })
  if let handler = channelB.makeHandler(executor: .immediate, block: handlerBlockB) {
    producer.insertToReleasePool(handler)
  }

  if let cancellationToken = cancellationToken {
    cancellationToken.notifyCancellation { [weak producer] in
      producer?.cancel()
    }
  }

  return producer
}

/// Merges channels into one
public func merge<PeriodicValue, SuccessValueA, SuccessValueB>(
  _ channelA: Channel<PeriodicValue, SuccessValueA>,
  _ channelB: Channel<PeriodicValue, SuccessValueB>,
  cancellationToken: CancellationToken? = nil,
  bufferSize: DerivedChannelBufferSize = .default
  ) -> Channel<PeriodicValue, (SuccessValueA, SuccessValueB)> {
  let bufferSize_ = bufferSize.bufferSize(channelA, channelB)
  let producer = Producer<PeriodicValue, (SuccessValueA, SuccessValueB)>(bufferSize: bufferSize_)

  var locking = makeLocking()
  var successA: SuccessValueA?
  var successB: SuccessValueB?

  func makeHandlerBlock<T>(_ successHandler: @escaping (T) -> Void
    ) -> (ChannelValue<PeriodicValue, T>) -> Void {
    return {
      [weak producer] (value) in
      switch value {
      case let .periodic(periodic):
        producer?.send(periodic)
      case let .final(.failure(error)):
        producer?.fail(with: error)
      case let .final(.success(localSuccess)):
        locking.lock()
        defer { locking.unlock() }
        successHandler(localSuccess)
        if let localSuccessA = successA, let localSuccessB = successB {
          producer?.succeed(with: (localSuccessA, localSuccessB))
        }
      }
    }
  }

  if let handler = channelA.makeHandler(executor: .immediate,
                                        block: makeHandlerBlock { successA = $0 }) {
    producer.insertToReleasePool(handler)
  }

  if let handler = channelB.makeHandler(executor: .immediate,
                                        block: makeHandlerBlock { successB = $0 }) {
    producer.insertToReleasePool(handler)
  }

  if let cancellationToken = cancellationToken {
    cancellationToken.notifyCancellation { [weak producer] in
      producer?.cancel()
    }
  }

  return producer
}
