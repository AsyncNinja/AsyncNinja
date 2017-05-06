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

// MARK: - sample

public extension EventSource {

  /// Samples the channel with specified channel
  ///
  /// - Parameters:
  ///   - samplerChannel: sampler
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: sampled channel
  func sample<P, S>(
    with samplerChannel: Channel<P, S>,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<(Update, P), (Success, S)> {

    // Test: EventSource_CombineTests.testSample
    var locking = makeLocking()
    var latestLeftUpdate: Update? = nil
    var leftSuccess: Success? = nil
    var rightSuccess: S? = nil

    let bufferSize_ = bufferSize.bufferSize(self, samplerChannel)
    let producer = Producer<(Update, P), (Success, S)>(bufferSize: bufferSize_)

    do {
      let handler = makeHandler(
        executor: .immediate
      ) { [weak producer] (event, originalExecutor) in
        locking.lock()
        defer { locking.unlock() }

        switch event {
        case let .update(localUpdate):
          latestLeftUpdate = localUpdate
        case let .completion(.success(localLeftSuccess)):
          if let localRightSuccess = rightSuccess {
            let success = (localLeftSuccess, localRightSuccess)
            producer?.succeed(success, from: originalExecutor)
          } else {
            leftSuccess = localLeftSuccess
          }
        case let .completion(.failure(error)):
          producer?.fail(error, from: originalExecutor)
        }
      }

      producer._asyncNinja_retainHandlerUntilFinalization(handler)
    }

    do {
      let handler = samplerChannel.makeHandler(
        executor: .immediate
      ) { [weak producer] (event, originalExecutor) in
        locking.lock()
        defer { locking.unlock() }

        switch event {
        case let .update(localRightUpdate):
          if let localLeftUpdate = latestLeftUpdate {
            producer?.update((localLeftUpdate, localRightUpdate), from: originalExecutor)
            latestLeftUpdate = nil
          }
        case let .completion(.success(localRightSuccess)):
          if let localLeftSuccess = leftSuccess {
            let success = (localLeftSuccess, localRightSuccess)
            producer?.succeed(success, from: originalExecutor)
          } else {
            rightSuccess = localRightSuccess
          }
        case let .completion(.failure(error)):
          producer?.fail(error, from: originalExecutor)
        }
      }

      producer._asyncNinja_retainHandlerUntilFinalization(handler)
    }

    return producer
  }
}

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
    let queue = Queue<Update>()

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
          let result = queue.clone()
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
