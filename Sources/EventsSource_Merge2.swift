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
public func merge<T: EventSource, U: EventSource>(
  _ channelA: T,
  _ channelB: U,
  cancellationToken: CancellationToken? = nil,
  bufferSize: DerivedChannelBufferSize = .default
  ) -> Channel<Either<T.Update, U.Update>, (T.Success, U.Success)> {

  // Tests: EventSource_Merge2Tests.testMergeIntsAndStrings

  let bufferSize_ = bufferSize.bufferSize(channelA, channelB)
  let producer = Producer<Either<T.Update, U.Update>, (T.Success, U.Success)>(bufferSize: bufferSize_)

  var locking = makeLocking()
  var successA: T.Success?
  var successB: U.Success?

  func makeHandlerBlock<Update, Success>(
    updateHandler: @escaping (_ update: Update, _ originalExecutor: Executor) -> Void,
    successHandler: @escaping (_ success: Success) -> (T.Success, U.Success)?
    ) -> (_ event: ChannelEvent<Update, Success>, _ originalExecutor: Executor) -> Void {
    return {
      [weak producer] (event, originalExecutor) in
      switch event {
      case let .update(update):
        updateHandler(update, originalExecutor)
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

  let handlerBlockA = makeHandlerBlock(updateHandler: { [weak producer] (update, originalExecutor) in producer?.update(.left(update), from: originalExecutor) },
                                       successHandler: { (success: T.Success) in
                                        successA = success
                                        return successB.map { (success, $0) }
  })

  let handlerA = channelA.makeHandler(executor: .immediate, handlerBlockA)
  producer._asyncNinja_retainHandlerUntilFinalization(handlerA)

  let handlerBlockB = makeHandlerBlock(updateHandler: { [weak producer] (update, originalExecutor) in producer?.update(.right(update), from: originalExecutor) },
                                       successHandler: { (success: U.Success) in
                                        successB = success
                                        return successA.map { ($0, success) }
  })
  let handlerB = channelB.makeHandler(executor: .immediate, handlerBlockB)
  producer._asyncNinja_retainHandlerUntilFinalization(handlerB)

  cancellationToken?.add(cancellable: producer)

  return producer
}

/// Merges channels into one
public func merge<T: EventSource, U: EventSource>(
  _ channelA: T,
  _ channelB: U,
  cancellationToken: CancellationToken? = nil,
  bufferSize: DerivedChannelBufferSize = .default
) -> Channel<T.Update, (T.Success, U.Success)> where T.Update == U.Update {

  // Tests: EventSource_Merge2Tests.testMergeInts

  let bufferSize_ = bufferSize.bufferSize(channelA, channelB)
  let producer = Producer<T.Update, (T.Success, U.Success)>(bufferSize: bufferSize_)

  var locking = makeLocking()
  var successA: T.Success?
  var successB: U.Success?

  func makeHandlerBlock<V>(_ successHandler: @escaping (V) -> (T.Success, U.Success)?
    ) -> (_ event: ChannelEvent<T.Update, V>, _ originalExecutor: Executor) -> Void {
    return {
      [weak producer] (event, originalExecutor) in
      switch event {
      case let .update(update):
        producer?.update(update, from: originalExecutor)
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

  let handlerA = channelA.makeHandler(executor: .immediate,
                                      makeHandlerBlock { (success: T.Success) in
                                        successA = success
                                        return successB.map { (success, $0) }
  })
  producer._asyncNinja_retainHandlerUntilFinalization(handlerA)
  
  
  let handlerB = channelB.makeHandler(executor: .immediate,
                                      makeHandlerBlock { (success: U.Success) in
                                        successB = success
                                        return successA.map { ($0, success) }
  })
  producer._asyncNinja_retainHandlerUntilFinalization(handlerB)
  cancellationToken?.add(cancellable: producer)
  
  return producer
}
