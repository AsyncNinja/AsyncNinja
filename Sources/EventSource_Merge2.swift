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

/// Merges channels into one
public func merge<T: EventSource, U: EventSource>(
  _ channelA: T,
  _ channelB: U,
  cancellationToken: CancellationToken? = nil,
  bufferSize: DerivedChannelBufferSize = .default
) -> Channel<T.Update, (T.Success, U.Success)> where T.Update == U.Update {

  // Test: EventSource_Merge2Tests.testMergeInts

  let bufferSize_ = bufferSize.bufferSize(channelA, channelB)
  let producer = Producer<T.Update, (T.Success, U.Success)>(bufferSize: bufferSize_)
  let weakProducer = WeakBox(producer)

  var locking = makeLocking()
  var successA: T.Success?
  var successB: U.Success?

  func makeHandlerBlock<V>(
    _ successHandler: @escaping (V) -> (T.Success, U.Success)?
    ) -> (
    _ event: ChannelEvent<T.Update, V>,
    _ originalExecutor: Executor
    ) -> Void {
      return {
        (event, originalExecutor) in
        guard case .some = weakProducer.value else { return }
        switch event {
        case let .update(update):
          weakProducer.value?.update(update, from: originalExecutor)
        case let .completion(.failure(error)):
          weakProducer.value?.fail(error, from: originalExecutor)
        case let .completion(.success(localSuccess)):
          locking.lock()
          defer { locking.unlock() }
          if let success = successHandler(localSuccess) {
            weakProducer.value?.succeed(success, from: originalExecutor)
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
