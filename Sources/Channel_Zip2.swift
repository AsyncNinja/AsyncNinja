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
  let queueOfUpdates = Queue<Either<PA, PB>>()
  var successA: SA?
  var successB: SB?

  func makeHandlerBlock<Update, Success>(
    updateHandler: @escaping (Update) -> (PA, PB)?,
    successHandler: @escaping (Success) -> (SA, SB)?
    ) -> (_ event: ChannelEvent<Update, Success>, _ originalExecutor: Executor) -> Void {
    return {
      [weak producer] (event, originalExecutor) in
      switch event {
      case let .update(update):
        locking.lock()
        defer { locking.unlock() }
        if let updateAB = updateHandler(update) {
          producer?.update(updateAB, from: originalExecutor)
        }
      case let .completion(.failure(error)):
        producer?.fail(with: error, from: originalExecutor)
      case let .completion(.success(localSuccess)):
        locking.lock()
        defer { locking.unlock() }
        if let success = successHandler(localSuccess) {
          producer?.succeed(with: success, from: originalExecutor)
        }
      }
    }
  }

  do {
    let handlerBlockA: (_ event: ChannelEvent<PA, SA>, _ originalExecutor: Executor) -> Void = makeHandlerBlock(
      updateHandler: {
        if let updateB = queueOfUpdates.first?.right {
          let _ = queueOfUpdates.pop()
          return ($0, updateB)
        } else {
          queueOfUpdates.push(.left($0))
          return nil
        }
    }, successHandler: {
      (success: SA) in
      successA = success
      return successB.map { (success, $0) }
    })

    let handler = channelA.makeHandler(executor: .immediate, handlerBlockA)
    producer.insertHandlerToReleasePool(handler)
  }

  do {
    let handlerBlockB: (_ event: ChannelEvent<PB, SB>, _ originalExecutor: Executor) -> Void = makeHandlerBlock(
      updateHandler: {
        if let updateA = queueOfUpdates.first?.left {
          let _ = queueOfUpdates.pop()
          return (updateA, $0)
        } else {
          queueOfUpdates.push(.right($0))
          return nil
        }
    }, successHandler: {
      (success: SB) in
      successB = success
      return successA.map { ($0, success) }
    })

    let handler = channelB.makeHandler(executor: .immediate, handlerBlockB)
    producer.insertHandlerToReleasePool(handler)
  }

  cancellationToken?.add(cancellable: producer)

  return producer
}
