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

  /// Adds indexes to periodic values of the channel
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: channel with tuple (index, periodic) as periodic value
  func enumerated(cancellationToken: CancellationToken? = nil,
                  bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<(Int, Periodic), Success> {

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

      var index: OSAtomic_int64_aligned64_t = -1
      return self.mapPeriodic(executor: .immediate,
                              cancellationToken: cancellationToken,
                              bufferSize: bufferSize)
      {
        let localIndex = Int(OSAtomicIncrement64(&index))
        return (localIndex, $0)
      }

    #else

      var locking = makeLocking()
      var index = 0
      return self.mapPeriodic(executor: .immediate,
                              cancellationToken: cancellationToken,
                              bufferSize: bufferSize)
      {
        locking.lock()
        defer { locking.unlock() }
        let localIndex = index
        index += 1
        return (localIndex, $0)
      }

    #endif
  }

  /// Makes channel of pairs of periodic values
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: channel with tuple (periodic, periodic) as periodic value
  func bufferedPairs(cancellationToken: CancellationToken? = nil,
                     bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<(Periodic, Periodic), Success> {
    var locking = makeLocking()
    var previousPeriodic: Periodic? = nil

    return self.makeProducer(executor: .immediate,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (value, producer) in
      switch value {
      case let .periodic(periodic):
        locking.lock()
        let _previousPeriodic = previousPeriodic
        previousPeriodic = periodic
        locking.unlock()

        if let previousPeriodic = _previousPeriodic {
          let change = (previousPeriodic, periodic)
          producer.send(change)
        }
      case let .completion(completion):
        producer.complete(with: completion)
      }
    }
  }

  /// Makes channel of arrays of periodic values
  ///
  /// - Parameters:
  ///   - capacity: number of periodic values of original channel used
  ///     as periodic value of derived channel
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: channel with [periodic] as periodic value
  func buffered(capacity: Int,
                cancellationToken: CancellationToken? = nil,
                bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<[Periodic], Success> {
    var buffer = [Periodic]()
    buffer.reserveCapacity(capacity)
    var locking = makeLocking()

    return self.makeProducer(executor: .immediate,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (value, producer) in
      locking.lock()

      switch value {
      case let .periodic(periodic):
        buffer.append(periodic)
        if capacity == buffer.count {
          let localBuffer = buffer
          buffer.removeAll(keepingCapacity: true)
          locking.unlock()
          producer.send(localBuffer)
        } else {
          locking.unlock()
        }
      case let .completion(completion):
        let localBuffer = buffer
        buffer.removeAll(keepingCapacity: false)
        locking.unlock()

        if !localBuffer.isEmpty {
          producer.send(localBuffer)
        }
        producer.complete(with: completion)
      }
    }
  }

  /// Makes channel that delays each value produced by originial channel
  ///
  /// - Parameters:
  ///   - timeout: in seconds to delay original channel by
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: delayed channel
  func delayedPeriodic(timeout: Double,
                       cancellationToken: CancellationToken? = nil,
                       bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<Periodic, Success> {
    return self.makeProducer(executor: .immediate,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (value: Value, producer: Producer<Periodic, Success>) -> Void in
      Executor.primary.execute(after: timeout) { [weak producer] in
        guard let producer = producer else { return }
        producer.apply(value)
      }
    }
  }

  /// Picks latest periodic value of the channel every interval and sends it
  ///
  /// - Parameters:
  ///   - deadline: to start picking peridic values after
  ///   - interval: interfal for picking latest periodic values
  ///   - leeway: leeway for timer
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  /// - Returns: channel
  func debounce(deadline: DispatchTime = DispatchTime.now(),
                interval: Double,
                leeway: DispatchTimeInterval? = nil,
                cancellationToken: CancellationToken? = nil,
                bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<Periodic, Success> {

    // Test: Channel_TransformTests.testDebounce
    let bufferSize_ = bufferSize.bufferSize(self)
    let producer = Producer<Periodic, Success>(bufferSize: bufferSize_)
    var locking = makeLocking()
    var latestPeriodic: Periodic? = nil
    var didSendFirstPeriodic = false

    let timer = DispatchSource.makeTimerSource()
    if let leeway = leeway {
      timer.scheduleRepeating(deadline: DispatchTime.now(), interval: interval, leeway: leeway)
    } else {
      timer.scheduleRepeating(deadline: DispatchTime.now(), interval: interval)
    }

    timer.setEventHandler { [weak producer] in
      locking.lock()
      if let periodic = latestPeriodic {
        latestPeriodic = nil
        locking.unlock()
        producer?.send(periodic)
      } else {
        locking.unlock()
      }
    }

    timer.resume()
    producer.insertToReleasePool(timer)

    let handler = self.makeHandler(executor: .immediate) {
      [weak producer] (value) in

      locking.lock()
      defer { locking.unlock() }

      switch value {
      case let .completion(completion):
        if let periodic = latestPeriodic {
          producer?.send(periodic)
          latestPeriodic = nil
        }
        producer?.complete(with: completion)
      case let .periodic(periodic):
        if didSendFirstPeriodic {
          latestPeriodic = periodic
        } else {
          didSendFirstPeriodic = true
          producer?.send(periodic)
        }
      }
    }

    self.insertHandlerToReleasePool(handler)
    cancellationToken?.add(cancellable: producer)

    return producer
  }
}

extension Channel where Periodic: Equatable {

  /// Returns channel of distinct periodic values of original channel.
  /// Works only for equatable periodic values
  /// [0, 0, 1, 2, 3, 3, 4, 3] => [0, 1, 2, 3, 4, 3]
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: channel with distinct periodic values
  public func distinct(cancellationToken: CancellationToken? = nil,
                       bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<Periodic, Success> {

    // Test: Channel_TransformTests.testDistinctInts
    
    var locking = makeLocking()
    var previousPeriodic: Periodic? = nil

    return self.makeProducer(executor: .immediate,
                             cancellationToken: cancellationToken,
                             bufferSize: bufferSize)
    {
      (value, producer) in
      switch value {
      case let .periodic(periodic):
        locking.lock()
        let _previousPeriodic = previousPeriodic
        previousPeriodic = periodic
        locking.unlock()


        if let previousPeriodic = _previousPeriodic {
          if previousPeriodic != periodic {
            producer.send(periodic)
          }
        } else {
          producer.send(periodic)
        }
      case let .completion(completion):
        producer.complete(with: completion)
      }
    }
  }
}
