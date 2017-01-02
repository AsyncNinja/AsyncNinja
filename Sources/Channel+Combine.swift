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
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  /// - Returns: sampled channel
  func sample<T, U>(
    with samplerChannel: Channel<T, U>,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<(PeriodicValue, T), (FinalValue, U)> {

    var locking = makeLocking()
    var latestLeftPeriodicValue: PeriodicValue? = nil
    var leftSuccessValue: FinalValue? = nil
    var rightSuccessValue: U? = nil

    let bufferSize_ = bufferSize.bufferSize(self, samplerChannel)
    let producer = Producer<(PeriodicValue, T), (FinalValue, U)>(bufferSize: bufferSize_)

    do {
      let handler = self.makeHandler(executor: .immediate) { [weak producer] (value) in
        locking.lock()
        defer { locking.unlock() }

        switch value {
        case let .periodic(localPeriodicValue):
          latestLeftPeriodicValue = localPeriodicValue
        case let .final(leftFinalValue):
          switch leftFinalValue {
          case let .success(localLeftSuccessValue):
            if let localRightSuccessValue = rightSuccessValue {
              producer?.succeed(with: (localLeftSuccessValue, localRightSuccessValue))
            } else {
              leftSuccessValue = localLeftSuccessValue
            }
          case let .failure(error):
            producer?.fail(with: error)
          }
        }
      }

      if let handler = handler {
        producer.insertToReleasePool(handler)
      }
    }

    do {
      let handler = samplerChannel.makeHandler(executor: .immediate) { [weak producer] (value) in
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
              producer?.succeed(with: (localLeftSuccessValue, localRightSuccessValue))
            } else {
              rightSuccessValue = localRightSuccessValue
            }
          case let .failure(error):
            producer?.fail(with: error)
          }
        }
      }

      if let handler = handler {
        producer.insertToReleasePool(handler)
      }
    }
    
    return producer
  }
}
