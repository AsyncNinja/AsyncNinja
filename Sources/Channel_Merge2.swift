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

/// Merges channels with completely unrelated types into one
public func merge<PA, PB, SA, SB>(_ channelA: Channel<PA, SA>,
                  _ channelB: Channel<PB, SB>,
                  cancellationToken: CancellationToken? = nil,
                  bufferSize: DerivedChannelBufferSize = .default
  ) -> Channel<Either<PA, PB>, (SA, SB)> {

  // Tests: Channel_Merge2Tests.testMergeIntsAndStrings

  let bufferSize_ = bufferSize.bufferSize(channelA, channelB)
  let producer = Producer<Either<PA, PB>, (SA, SB)>(bufferSize: bufferSize_)

  var locking = makeLocking()
  var successA: SA?
  var successB: SB?

  func makeHandlerBlock<Periodic, Success>(
    periodicHandler: @escaping (Periodic) -> Void,
    successHandler: @escaping (Success) -> (SA, SB)?
    ) -> (ChannelValue<Periodic, Success>) -> Void {
    return {
      [weak producer] (value) in
      switch value {
      case let .periodic(periodic):
        periodicHandler(periodic)
      case let .completion(.failure(error)):
        producer?.fail(with: error)
      case let .completion(.success(localSuccess)):
        locking.lock()
        defer { locking.unlock() }
        if let success = successHandler(localSuccess) {
          producer?.succeed(with: success)
        }
      }
    }
  }

    let handlerBlockA = makeHandlerBlock(periodicHandler: { [weak producer] in producer?.send(.left($0)) },
                                         successHandler: { (success: SA) in
                                            successA = success
                                            return successB.map { (success, $0) }
    })

  let handlerA = channelA.makeHandler(executor: .immediate, handlerBlockA)
  producer.insertHandlerToReleasePool(handlerA)

  let handlerBlockB = makeHandlerBlock(periodicHandler: { [weak producer] in producer?.send(.right($0)) },
                                       successHandler: { (success: SB) in
                                        successB = success
                                        return successA.map { ($0, success) }
  })
  let handlerB = channelB.makeHandler(executor: .immediate, handlerBlockB)
  producer.insertHandlerToReleasePool(handlerB)

  cancellationToken?.add(cancellable: producer)

  return producer
}

/// Merges channels into one
public func merge<P, SA, SB>(_ channelA: Channel<P, SA>,
                  _ channelB: Channel<P, SB>,
                  cancellationToken: CancellationToken? = nil,
                  bufferSize: DerivedChannelBufferSize = .default
  ) -> Channel<P, (SA, SB)> {

  // Tests: Channel_Merge2Tests.testMergeInts

  let bufferSize_ = bufferSize.bufferSize(channelA, channelB)
  let producer = Producer<P, (SA, SB)>(bufferSize: bufferSize_)

  var locking = makeLocking()
  var successA: SA?
  var successB: SB?

  func makeHandlerBlock<T>(_ successHandler: @escaping (T) -> (SA, SB)?
    ) -> (ChannelValue<P, T>) -> Void {
    return {
      [weak producer] (value) in
      switch value {
      case let .periodic(periodic):
        producer?.send(periodic)
      case let .completion(.failure(error)):
        producer?.fail(with: error)
      case let .completion(.success(localSuccess)):
        locking.lock()
        defer { locking.unlock() }
        if let success = successHandler(localSuccess) {
            producer?.succeed(with: success)
        }
      }
    }
  }

  let handlerA = channelA.makeHandler(executor: .immediate,
                                      makeHandlerBlock { (success: SA) in
                                        successA = success
                                        return successB.map { (success, $0) }
  })
  producer.insertHandlerToReleasePool(handlerA)
  
  
  let handlerB = channelB.makeHandler(executor: .immediate,
                                      makeHandlerBlock { (success: SB) in
                                        successB = success
                                        return successA.map { ($0, success) }
  })
  producer.insertHandlerToReleasePool(handlerB)
  cancellationToken?.add(cancellable: producer)
  
  return producer
}
