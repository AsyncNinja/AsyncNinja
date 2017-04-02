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

public extension EventSource {

  /// Samples the channel with specified channel
  ///
  /// - Parameters:
  ///   - samplerChannel: sampler
  ///   - cancellationToken: `CancellationToken` to use. Keep default value
  ///     of the argument unless you need an extended cancellation options
  ///     of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: sampled channel
  func sample<P, S>(with samplerChannel: Channel<P, S>,
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
      let handler = makeHandler(executor: .immediate) {
        [weak producer] (event, originalExecutor) in
        locking.lock()
        defer { locking.unlock() }

        switch event {
        case let .update(localUpdate):
          latestLeftUpdate = localUpdate
        case let .completion(leftCompletion):
          switch leftCompletion {
          case let .success(localLeftSuccess):
            if let localRightSuccess = rightSuccess {
              let success = (localLeftSuccess, localRightSuccess)
              producer?.succeed(success, from: originalExecutor)
            } else {
              leftSuccess = localLeftSuccess
            }
          case let .failure(error):
            producer?.fail(error, from: originalExecutor)
          }
        }
      }

      producer._asyncNinja_retainHandlerUntilFinalization(handler)
    }

    do {
      let handler = samplerChannel.makeHandler(executor: .immediate) {
        [weak producer] (event, originalExecutor) in
        locking.lock()
        defer { locking.unlock() }

        switch event {
        case let .update(localRightUpdate):
          if let localLeftUpdate = latestLeftUpdate {
            producer?.update((localLeftUpdate, localRightUpdate), from: originalExecutor)
            latestLeftUpdate = nil
          }
        case let .completion(rightCompletion):
          switch rightCompletion {
          case let .success(localRightSuccess):
            if let localLeftSuccess = leftSuccess {
              let success = (localLeftSuccess, localRightSuccess)
              producer?.succeed(success, from: originalExecutor)
            } else {
              rightSuccess = localRightSuccess
            }
          case let .failure(error):
            producer?.fail(error, from: originalExecutor)
          }
        }
      }

      producer._asyncNinja_retainHandlerUntilFinalization(handler)
    }
    
    return producer
  }
}
