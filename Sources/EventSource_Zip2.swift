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
    func updateHandler(update: T.Update) -> (T.Update, U.Update)? {
      if let updateB = queueOfUpdates.first?.right {
        _ = queueOfUpdates.pop()
        return (update, updateB)
      } else {
        queueOfUpdates.push(.left(update))
        return nil
      }
    }

    func successHandler(success: T.Success) -> (T.Success, U.Success)? {
      successA = success
      return successB.map { (success, $0) }
    }

    let handlerBlock = makeHandlerBlock(updateHandler: updateHandler, successHandler: successHandler)
    let handler = channelA.makeHandler(executor: .immediate, handlerBlock)
    producer._asyncNinja_retainHandlerUntilFinalization(handler)
  }

  do {
    func updateHandler(update: U.Update) -> (T.Update, U.Update)? {
      if let updateA = queueOfUpdates.first?.left {
        _ = queueOfUpdates.pop()
        return (updateA, update)
      } else {
        queueOfUpdates.push(.right(update))
        return nil
      }
    }

    func successHandler(success: U.Success) -> (T.Success, U.Success)? {
      successB = success
      return successA.map { ($0, success) }
    }

    let handlerBlock = makeHandlerBlock(updateHandler: updateHandler, successHandler: successHandler)
    let handler = channelB.makeHandler(executor: .immediate, handlerBlock)
    producer._asyncNinja_retainHandlerUntilFinalization(handler)
  }

  cancellationToken?.add(cancellable: producer)

  return producer
}
