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
  func sample<Sampler: EventSource>(
    with sampler: Sampler,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<(Update, Sampler.Update), (Success, Sampler.Success)> {

    // Test: EventSource_CombineTests.testSample
    typealias Destination = Producer<(Update, Sampler.Update), (Success, Sampler.Success)>
    let producer = Destination(bufferSize: bufferSize.bufferSize(self, sampler))
    cancellationToken?.add(cancellable: producer)

    let helper = SamplingHelper<Self, Sampler, Destination>(destination: producer)
    producer._asyncNinja_retainHandlerUntilFinalization(helper.handle(sampled: self))
    producer._asyncNinja_retainHandlerUntilFinalization(helper.handle(sampler: sampler))
    return producer
  }
}

/// **internal use only**
/// Encapsulates sampling behavior
private class SamplingHelper<Sampled: EventSource, Sampler: EventSource, Destination: EventDestination> where
Destination.Update == (Sampled.Update, Sampler.Update),
Destination.Success == (Sampled.Success, Sampler.Success) {
  var locking = makeLocking()
  var latestLeftUpdate: Sampled.Update?
  var leftSuccess: Sampled.Success?
  var rightSuccess: Sampler.Success?
  weak var destination: Destination?

  init(destination: Destination) {
    self.destination = destination
  }

  func handle(sampled: Sampled) -> AnyObject? {
    // `self` is being captured but it is okay
    // because it does not retain valuable resources

    return sampled.makeHandler(executor: .immediate) { (event, originalExecutor) in
      self.locking.lock()
      defer { self.locking.unlock() }

      switch event {
      case let .update(localUpdate):
        self.latestLeftUpdate = localUpdate
      case let .completion(.success(localLeftSuccess)):
        if let localRightSuccess = self.rightSuccess {
          let success = (localLeftSuccess, localRightSuccess)
          self.destination?.succeed(success, from: originalExecutor)
        } else {
          self.leftSuccess = localLeftSuccess
        }
      case let .completion(.failure(error)):
        self.destination?.fail(error, from: originalExecutor)
      }
    }
  }

  func handle(sampler: Sampler) -> AnyObject? {
    // `self` is being captured but it is okay
    // because it does not retain valuable resources

    return sampler.makeHandler(executor: .immediate) {(event, originalExecutor) in
      self.locking.lock()
      defer { self.locking.unlock() }

      switch event {
      case let .update(localRightUpdate):
        if let localLeftUpdate = self.latestLeftUpdate {
          self.destination?.update((localLeftUpdate, localRightUpdate), from: originalExecutor)
          self.latestLeftUpdate = nil
        }
      case let .completion(.success(localRightSuccess)):
        if let localLeftSuccess = self.leftSuccess {
          let success = (localLeftSuccess, localRightSuccess)
          self.destination?.succeed(success, from: originalExecutor)
        } else {
          self.rightSuccess = localRightSuccess
        }
      case let .completion(.failure(error)):
        self.destination?.fail(error, from: originalExecutor)
      }
    }
  }
}
