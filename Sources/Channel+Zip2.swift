//
//  Copyright (c) 2017 Anton Mironov
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

/// Zips two channels into channels of tuples
public func zip<PA, PB, SA, SB>(_ channelA: Channel<PA, SA>,
                _ channelB: Channel<PB, SB>,
                cancellationToken: CancellationToken? = nil,
                bufferSize: DerivedChannelBufferSize = .default
  ) -> Channel<(PA, PB), (SA, SB)> {
  let bufferSize_ = bufferSize.bufferSize(channelA, channelB)
  let producer = Producer<(PA, PB), (SA, SB)>(bufferSize: bufferSize_)

  var locking = makeLocking()
  let queueOfPeriodics = QueueImpl<Either<PA, PB>>()
  var successA: SA?
  var successB: SB?

  func makeHandlerBlock<PeriodicValue, SuccessValue>(
    periodicHandler: @escaping (PeriodicValue) -> (PA, PB)?,
    successHandler: @escaping (SuccessValue) -> Void
    ) -> (ChannelValue<PeriodicValue, SuccessValue>) -> Void {
    return {
      [weak producer] (value) in
      switch value {
      case let .periodic(periodic):
        locking.lock()
        defer { locking.unlock() }
        if let periodicAB = periodicHandler(periodic) {
          producer?.send(periodicAB)
        }
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

  do {
    let handlerBlockA: (ChannelValue<PA, SA>) -> Void = makeHandlerBlock(
      periodicHandler: {
        if let periodicB = queueOfPeriodics.first?.right {
          let _ = queueOfPeriodics.pop()
          return ($0, periodicB)
        } else {
          queueOfPeriodics.push(.left($0))
          return nil
        }
    }, successHandler: { successA = $0 })

    let handler = channelA.makeHandler(executor: .immediate,
                                       block: handlerBlockA)
    producer.insertHandlerToReleasePool(handler)
  }

  do {
    let handlerBlockB: (ChannelValue<PB, SB>) -> Void = makeHandlerBlock(
      periodicHandler: {
        if let periodicA = queueOfPeriodics.first?.left {
          let _ = queueOfPeriodics.pop()
          return (periodicA, $0)
        } else {
          queueOfPeriodics.push(.right($0))
          return nil
        }
    }, successHandler: { successB = $0 })

    let handler = channelB.makeHandler(executor: .immediate,
                                       block: handlerBlockB)
    producer.insertHandlerToReleasePool(handler)
  }

  cancellationToken?.add(cancellable: producer)
  
  return producer
}
