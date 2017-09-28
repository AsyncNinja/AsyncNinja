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

// MARK: - suspendable

public extension EventSource {

  /// Makes a suspendable channel
  /// Returned channel will be suspended by a signal from a suspensionController
  ///
  /// - Parameters:
  ///   - suspensionController: EventSource to control suspension with.
  ///     Updates of the returned channel are delivered when
  ///     the lates update for suspensionController was `true`.
  ///   - suspensionBufferSize: amount of updates to buffer when channel is suspended
  ///   - isSuspendedInitially: tells if returned channel is initially suspended
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: suspendable channel.
  func suspendable<T: EventSource>(
    _ suspensionController: T,
    suspensionBufferSize: Int = 1,
    isSuspendedInitially: Bool = true,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<Update, Success>
    where T.Update == Bool {
    // Test: EventSource_CombineTests.testSuspendable
    var locking = makeLocking(isFair: true)
    var isUnsuspended = !isSuspendedInitially
    var queue = Queue<Update>()

    func onEvent(
      event: ChannelEvent<Update, Success>,
      producerBox: WeakBox<BaseProducer<Update, Success>>,
      originalExecutor: Executor) {
      switch event {
      case let .update(update):
        let update: Update? = locking.locker {
          if isUnsuspended {
            return update
          } else {
            if suspensionBufferSize > 0 {
              queue.push(update)
              while queue.count > suspensionBufferSize {
                _ = queue.pop()
              }
            }
            return nil
          }
        }
        if let update = update {
          producerBox.value?.update(update, from: originalExecutor)
        }
      case let .completion(completion):
        producerBox.value?.complete(completion, from: originalExecutor)
      }
    }

    let producer = makeProducer(executor: .immediate, pure: true,
                        cancellationToken: cancellationToken,
                        bufferSize: bufferSize, onEvent)

      let handler = suspensionController.makeUpdateHandler(
        executor: .immediate
      ) { [weak producer] (isUnsuspendedLocal, _) in
        let updates: Queue<Update>? = locking.locker {
          isUnsuspended = isUnsuspendedLocal
          guard isUnsuspendedLocal else { return nil }
          let result = queue
          queue.removeAll()
          return result
        }
        if let updates = updates {
          producer?.update(updates)
        }
      }
      producer._asyncNinja_retainHandlerUntilFinalization(handler)
      return producer
  }
}
