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

public extension Channel {
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
    ) -> Channel<(PeriodicValue, P), (SuccessValue, S)> {

    // Test: Channel_CombineTests.testSample
    var locking = makeLocking()
    var latestLeftPeriodicValue: PeriodicValue? = nil
    var leftSuccessValue: SuccessValue? = nil
    var rightSuccessValue: S? = nil

    let bufferSize_ = bufferSize.bufferSize(self, samplerChannel)
    let producer = Producer<(PeriodicValue, P), (SuccessValue, S)>(bufferSize: bufferSize_)

    do {
      let handler = makeHandler(executor: .immediate) {
        [weak producer] (value) in
        locking.lock()
        defer { locking.unlock() }

        switch value {
        case let .periodic(localPeriodicValue):
          latestLeftPeriodicValue = localPeriodicValue
        case let .final(leftFinalValue):
          switch leftFinalValue {
          case let .success(localLeftSuccessValue):
            if let localRightSuccessValue = rightSuccessValue {
              let success = (localLeftSuccessValue, localRightSuccessValue)
              producer?.succeed(with: success)
            } else {
              leftSuccessValue = localLeftSuccessValue
            }
          case let .failure(error):
            producer?.fail(with: error)
          }
        }
      }

      producer.insertHandlerToReleasePool(handler)
    }

    do {
      let handler = samplerChannel.makeHandler(executor: .immediate) {
        [weak producer] (value) in
        locking.lock()
        defer { locking.unlock() }

        switch value {
        case let .periodic(localRightPeriodicValue):
          if let localLeftPeriodicValue = latestLeftPeriodicValue {
            producer?.send((localLeftPeriodicValue, localRightPeriodicValue))
            latestLeftPeriodicValue = nil
          }
        case let .final(rightFinalValue):
          switch rightFinalValue {
          case let .success(localRightSuccessValue):
            if let localLeftSuccessValue = leftSuccessValue {
              let success = (localLeftSuccessValue, localRightSuccessValue)
              producer?.succeed(with: success)
            } else {
              rightSuccessValue = localRightSuccessValue
            }
          case let .failure(error):
            producer?.fail(with: error)
          }
        }
      }

      producer.insertHandlerToReleasePool(handler)
    }
    
    return producer
  }
}
