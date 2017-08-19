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

  /// Picks latest update value of the channel every interval and sends it
  ///
  /// - Parameters:
  ///   - deadline: to start picking peridic values after
  ///   - interval: interfal for picking latest update values
  ///   - leeway: leeway for timer
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  /// - Returns: channel
  func debounce(
    deadline: DispatchTime = DispatchTime.now(),
    interval: Double,
    leeway: DispatchTimeInterval? = nil,
    qos: DispatchQoS.QoSClass = .default,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<Update, Success> {
    // Test: EventSource_TransformTests.testDebounce

    typealias Destination = Producer<Update, Success>
    let producer = Destination(bufferSize: bufferSize.bufferSize(self))
    cancellationToken?.add(cancellable: producer)

    let helper = DebounceEventSourceHelper<Self, Destination>(
      destination: producer,
      deadline: deadline,
      interval: interval,
      leeway: leeway,
      qos: qos)

    producer._asyncNinja_retainHandlerUntilFinalization(helper.makeHandler(source: self))

    return producer
  }
}

private class DebounceEventSourceHelper<Source: EventSource, Destination: EventDestination>
where Source.Update == Destination.Update, Source.Success == Destination.Success {
  var locking = makeLocking()
  var latestUpdate: Source.Update?
  var didSendFirstUpdate = false
  weak var destination: Destination?

  init(
    destination: Destination,
    deadline: DispatchTime,
    interval: Double,
    leeway: DispatchTimeInterval?,
    qos: DispatchQoS.QoSClass
    ) {
    self.destination = destination

    let queue = DispatchQueue.global(qos: qos)
    let executor = Executor.queue(queue)
    let timer = DispatchSource.makeTimerSource(queue: queue)
    #if swift(>=4.0)
      if let leeway = leeway {
      timer.schedule(deadline: deadline, repeating: interval, leeway: leeway)
      } else {
      timer.schedule(deadline: deadline, repeating: interval)
      }
    #else
      if let leeway = leeway {
        timer.scheduleRepeating(deadline: deadline, interval: interval, leeway: leeway)
      } else {
        timer.scheduleRepeating(deadline: deadline, interval: interval)
      }
    #endif

    timer.setEventHandler {
      self.locking.lock()
      if let update = self.latestUpdate {
        self.latestUpdate = nil
        self.locking.unlock()
        self.destination?.update(update, from: executor)
      } else {
        self.locking.unlock()
      }
    }

    timer.resume()
    destination._asyncNinja_retainUntilFinalization(timer)
  }

  func makeHandler(source: Source) -> AnyObject? {
    return source.makeHandler(executor: .immediate) { (event, originalExecutor) in

      self.locking.lock()
      defer { self.locking.unlock() }

      switch event {
      case let .completion(completion):
        if let update = self.latestUpdate {
          self.destination?.update(update, from: originalExecutor)
          self.latestUpdate = nil
        }
        self.destination?.complete(completion, from: originalExecutor)
      case let .update(update):
        if self.didSendFirstUpdate {
          self.latestUpdate = update
        } else {
          self.didSendFirstUpdate = true
          self.destination?.update(update, from: originalExecutor)
        }
      }
    }
  }
}
