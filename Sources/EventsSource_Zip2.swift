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
public func zip<T: EventSource, U: EventSource>(
  _ channelA: T,
  _ channelB: U,
  cancellationToken: CancellationToken? = nil,
  bufferSize: DerivedChannelBufferSize = .default
  ) -> Channel<(T.Update, U.Update), (T.Success, U.Success)> {
  let bufferSize_ = bufferSize.bufferSize(channelA, channelB)
  let producer = Producer<(T.Update, U.Update), (T.Success, U.Success)>(bufferSize: bufferSize_)

  var locking = makeLocking()
  let queueOfUpdates = Queue<Either<T.Update, U.Update>>()
  var successA: T.Success?
  var successB: U.Success?

  func makeHandlerBlock<Update, Success>(
    updateHandler: @escaping (Update) -> (T.Update, U.Update)?,
    successHandler: @escaping (Success) -> (T.Success, U.Success)?
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
        producer?.fail(error, from: originalExecutor)
      case let .completion(.success(localSuccess)):
        locking.lock()
        defer { locking.unlock() }
        if let success = successHandler(localSuccess) {
          producer?.succeed(success, from: originalExecutor)
        }
      }
    }
  }

  do {
    let handlerBlockA: (_ event: T.Event, _ originalExecutor: Executor) -> Void = makeHandlerBlock(
      updateHandler: {
        if let updateB = queueOfUpdates.first?.right {
          let _ = queueOfUpdates.pop()
          return ($0, updateB)
        } else {
          queueOfUpdates.push(.left($0))
          return nil
        }
    }, successHandler: {
      (success: T.Success) in
      successA = success
      return successB.map { (success, $0) }
    })

    let handler = channelA.makeHandler(executor: .immediate, handlerBlockA)
    producer._asyncNinja_retainHandlerUntilFinalization(handler)
  }

  do {
    let handlerBlockB: (_ event: U.Event, _ originalExecutor: Executor) -> Void = makeHandlerBlock(
      updateHandler: {
        if let updateA = queueOfUpdates.first?.left {
          let _ = queueOfUpdates.pop()
          return (updateA, $0)
        } else {
          queueOfUpdates.push(.right($0))
          return nil
        }
    }, successHandler: {
      (success: U.Success) in
      successB = success
      return successA.map { ($0, success) }
    })

    let handler = channelB.makeHandler(executor: .immediate, handlerBlockB)
    producer._asyncNinja_retainHandlerUntilFinalization(handler)
  }

  cancellationToken?.add(cancellable: producer)

  return producer
}
