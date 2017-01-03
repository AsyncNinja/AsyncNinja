//
//  Copyright (c) 2017 Anton Mironov
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

// MARK: - channel first(where:)

public extension Channel {

  /// **internal use only**
  private func _first(executor: Executor,
                      cancellationToken: CancellationToken?,
                      `where` predicate: @escaping(PeriodicValue) throws -> Bool) -> Promise<PeriodicValue?> {

    let promise = Promise<PeriodicValue?>()
    let handler = self.makeHandler(executor: executor) { [weak promise] in
      switch $0 {
      case let .periodic(periodicValue):
        do {
          if try predicate(periodicValue) {
            promise?.succeed(with: periodicValue)
          }
        } catch {
          promise?.fail(with: error)
        }
      case .final(.success):
        promise?.succeed(with: nil)
      case let .final(.failure(failureValue)):
        promise?.fail(with: failureValue)
      }
    }

    if let handler = handler {
      promise.insertToReleasePool(handler)
    }

    cancellationToken?.notifyCancellation { [weak promise] in
      promise?.cancel()
    }

    return promise
  }

  /// Returns future of first periodic value matching predicate
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor. Do not use this argument if you do not need to override executor
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - predicate: returns true if periodic value matches and returned future may be completed with it
  /// - Returns: future
  func first<U: ExecutionContext>(context: U,
             executor: Executor? = nil,
             cancellationToken: CancellationToken? = nil,
             `where` predicate: @escaping(U, PeriodicValue) throws -> Bool
    ) -> Future<PeriodicValue?> {
    let promise = self._first(executor: executor ?? context.executor, cancellationToken: cancellationToken) {
      [weak context] (periodicValue) -> Bool in
      guard let context = context else { throw AsyncNinjaError.contextDeallocated }
      return try predicate(context, periodicValue)
    }

    context.notifyDeinit { [weak promise] in
      promise?.cancelBecauseOfDeallocatedContext()
    }

    return promise
  }

  /// Returns future of first periodic value matching predicate
  ///
  /// - Parameters:
  ///   - executor: to execute call predicate on
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - predicate: returns true if periodic value matches and returned future may be completed with it
  /// - Returns: future
  func first(executor: Executor = .immediate,
             cancellationToken: CancellationToken? = nil,
             `where` predicate: @escaping(PeriodicValue) throws -> Bool) -> Future<PeriodicValue?> {
    return _first(executor: executor, cancellationToken: cancellationToken, where: predicate)
  }
}

extension Channel where PeriodicValue : Equatable {

  /// Returns channel of distinct periodic values of original channel. Works only for equatable periodic values [0, 0, 1, 2, 3, 3, 4, 3] => [0, 1, 2, 3, 4, 3]
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use. Do not use this argument if you do not need extended cancellation options of returned channel
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channe. Do not use this argument if you do not need extended buffering options of returned channel
  /// - Returns: channel with distinct periodic values
  public func distinct(
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<(PeriodicValue, PeriodicValue), FinalValue> {
    var locking = makeLocking()
    var previousPeriodic: PeriodicValue? = nil

    return self.makeProducer(executor: .immediate, cancellationToken: cancellationToken, bufferSize: bufferSize) {
      (value, producer) in
      switch value {
      case let .periodic(periodic):
        locking.lock()
        let _previousPeriodic = previousPeriodic
        previousPeriodic = periodic
        locking.unlock()

        if let previousPeriodic = _previousPeriodic,
          previousPeriodic != periodic {
          let change = (previousPeriodic, periodic)
          producer.send(change)
        }
      case let .final(final):
        producer.complete(with: final)
      }
    }
  }
}
