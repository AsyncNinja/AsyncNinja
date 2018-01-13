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

  /// Adds indexes to update values of the channel
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: channel with tuple (index, update) as update value
  func enumerated(cancellationToken: CancellationToken? = nil,
                  bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<(Int, Update), Success> {

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

      var index: OSAtomic_int64_aligned64_t = -1
      return self.map(executor: .immediate,
                      cancellationToken: cancellationToken,
                      bufferSize: bufferSize) {
        let localIndex = Int(OSAtomicIncrement64(&index))
        return (localIndex, $0)
      }

    #else

      var locking = makeLocking()
      var index = 0
      return self.map(executor: .immediate,
                      cancellationToken: cancellationToken,
                      bufferSize: bufferSize) {
        locking.lock()
        defer { locking.unlock() }
        let localIndex = index
        index += 1
        return (localIndex, $0)
      }

    #endif
  }

  /// Makes channel of pairs of update values
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: channel with tuple (update, update) as update value
  func bufferedPairs(cancellationToken: CancellationToken? = nil,
                     bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<(Update, Update), Success>
  {
    var locking = makeLocking()
    var previousUpdate: Update? = nil

    return makeProducer(
      executor: .immediate,
      pure: true,
      cancellationToken: cancellationToken,
      bufferSize: bufferSize
    ) { (value, producer, originalExecutor) in
      switch value {
      case let .update(update):
        locking.lock()
        let _previousUpdate = previousUpdate
        previousUpdate = update
        locking.unlock()

        if let previousUpdate = _previousUpdate {
          let change = (previousUpdate, update)
          producer.value?.update(change, from: originalExecutor)
        }
      case let .completion(completion):
        producer.value?.complete(completion, from: originalExecutor)
      }
    }
  }

  /// Makes channel of arrays of update values
  ///
  /// - Parameters:
  ///   - capacity: number of update values of original channel used
  ///     as update value of derived channel
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: channel with [update] as update value
  func buffered(capacity: Int,
                cancellationToken: CancellationToken? = nil,
                bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<[Update], Success> {
    var buffer = [Update]()
    buffer.reserveCapacity(capacity)
    var locking = makeLocking()

    return makeProducer(
      executor: .immediate,
      pure: true,
      cancellationToken: cancellationToken,
      bufferSize: bufferSize
    ) { (value, producer, originalExecutor) in
      locking.lock()

      switch value {
      case let .update(update):
        buffer.append(update)
        if capacity == buffer.count {
          let localBuffer = buffer
          buffer.removeAll(keepingCapacity: true)
          locking.unlock()
          producer.value?.update(localBuffer, from: originalExecutor)
        } else {
          locking.unlock()
        }
      case let .completion(completion):
        let localBuffer = buffer
        buffer.removeAll(keepingCapacity: false)
        locking.unlock()

        if !localBuffer.isEmpty {
          producer.value?.update(localBuffer, from: originalExecutor)
        }
        producer.value?.complete(completion, from: originalExecutor)
      }
    }
  }

  /// Makes channel that delays each value produced by originial channel
  ///
  /// - Parameters:
  ///   - timeout: in seconds to delay original channel by
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: delayed channel
  func delayedUpdate(timeout: Double,
                     delayingExecutor: Executor = .primary,
                     cancellationToken: CancellationToken? = nil,
                     bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<Update, Success> {
    return makeProducer(
      executor: .immediate,
      pure: true,
      cancellationToken: cancellationToken,
      bufferSize: bufferSize
    ) { (event: Event, producer, originalExecutor: Executor) -> Void in
      delayingExecutor.execute(after: timeout) { (originalExecutor) in
        producer.value?.post(event, from: originalExecutor)
      }
    }
  }
}

// MARK: - Distinct

extension EventSource {
  /// Returns channel of distinct update values of original channel.
  /// Requires dedicated equality checking closure
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  ///   - isEqual: closure that tells if specified values are equal
  /// - Returns: channel with distinct update values
  public func distinct(
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default,
    isEqual: @escaping (Update, Update) -> Bool
    ) -> Channel<Update, Success> {
    var locking = makeLocking()
    var previousUpdate: Update? = nil

    return makeProducer(
      executor: .immediate,
      pure: true,
      cancellationToken: cancellationToken,
      bufferSize: bufferSize
    ) { (value, producer, originalExecutor) in
      switch value {
      case let .update(update):
        locking.lock()
        let _previousUpdate = previousUpdate
        previousUpdate = update
        locking.unlock()

        if let previousUpdate = _previousUpdate {
          if !isEqual(previousUpdate, update) {
            producer.value?.update(update, from: originalExecutor)
          }
        } else {
          producer.value?.update(update, from: originalExecutor)
        }
      case let .completion(completion):
        producer.value?.complete(completion, from: originalExecutor)
      }
    }
  }
}

extension EventSource where Update: Equatable {

  /// Returns channel of distinct update values of original channel.
  /// Works only for equatable update values
  /// [0, 0, 1, 2, 3, 3, 4, 3] => [0, 1, 2, 3, 4, 3]
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: channel with distinct update values
  public func distinct(
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<Update, Success> {
    // Test: EventSource_TransformTests.testDistinctInts
    return distinct(cancellationToken: cancellationToken, bufferSize: bufferSize, isEqual: ==)
  }
}

#if swift(>=4.1)
#else
extension EventSource where Update: AsyncNinjaOptionalAdaptor, Update.AsyncNinjaWrapped: Equatable {

  /// Returns channel of distinct update values of original channel.
  /// Works only for equatable wrapped in optionals
  /// [nil, 1, nil, nil, 2, 2, 3, nil, 3, 3, 4, 5, 6, 6, 7] => [nil, 1, nil, 2, 3, nil, 3, 4, 5, 6, 7]
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: channel with distinct update values
  public func distinct(
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<Update, Success> {

    // Test: EventSource_TransformTests.testDistinctInts
    return distinct(cancellationToken: cancellationToken, bufferSize: bufferSize) {
      $0.asyncNinjaOptionalValue == $1.asyncNinjaOptionalValue
    }
  }
}

extension EventSource where Update: Collection, Update.Iterator.Element: Equatable {

  /// Returns channel of distinct update values of original channel.
  /// Works only for collections of equatable values
  /// [[1], [1], [1, 2], [1, 2, 3], [1, 2, 3], [1]] => [[1], [1, 2], [1, 2, 3], [1]]
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: channel with distinct update values
  public func distinct(
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<Update, Success> {
    // Test: EventSource_TransformTests.testDistinctArray

    func isEqual(lhs: Update, rhs: Update) -> Bool {
      return lhs.count == rhs.count
        && !zip(lhs, rhs).contains { $0.0 != $0.1 }
    }
    return distinct(cancellationToken: cancellationToken, bufferSize: bufferSize, isEqual: isEqual)
  }
}
#endif

// MARK: - skip

public extension EventSource {
  /// Makes a channel that skips updates
  ///
  /// - Parameters:
  ///   - first: number of first updates to skip
  ///   - last: number of last updates to skip
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: channel that skips updates
  func skip(
    first: Int,
    last: Int,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<Update, Success> {
    // Test: EventSource_TransformTests.testSkip
    var locking = makeLocking(isFair: true)
    var updatesQueue = Queue<Update>()
    var numberOfFirstToSkip = first
    let numberOfLastToSkip = last

    func onEvent(
      event: ChannelEvent<Update, Success>,
      producerBox: WeakBox<BaseProducer<Update, Success>>,
      originalExecutor: Executor) {
      switch event {
      case let .update(update):
        let updateToPost: Update? = locking.locker {
          if numberOfFirstToSkip > 0 {
            numberOfFirstToSkip -= 1
            return nil
          } else if numberOfLastToSkip > 0 {
            updatesQueue.push(update)
            while updatesQueue.count > numberOfLastToSkip {
              return updatesQueue.pop()
            }
            return nil
          } else {
            return update
          }
        }

        if let updateToPost = updateToPost {
          producerBox.value?.update(updateToPost, from: originalExecutor)
        }
      case let .completion(completion):
        producerBox.value?.complete(completion, from: originalExecutor)
      }
    }

    return makeProducer(executor: .immediate, pure: true,
                        cancellationToken: cancellationToken,
                        bufferSize: bufferSize, onEvent)
  }
}

// MARK: take

public extension EventSource {
  /// Makes a channel that takes updates specific number of update
  ///
  /// - Parameters:
  ///   - first: number of first updates to take
  ///   - last: number of last updates to take
  ///   - cancellationToken: `CancellationToken` to use.
  ///     Keep default value of the argument unless you need
  ///     an extended cancellation options of returned primitive
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: channel that takes updates
  func take(
    first: Int,
    last: Int,
    cancellationToken: CancellationToken? = nil,
    bufferSize: DerivedChannelBufferSize = .default
    ) -> Channel<Update, Success> {
    // Test: EventSource_TransformTests.testTake
    var locking = makeLocking(isFair: true)
    var updatesQueue = Queue<Update>()
    var numberOfFirstToTake = first
    let numberOfLastToTake = last

    func onEvent(
      event: ChannelEvent<Update, Success>,
      producerBox: WeakBox<BaseProducer<Update, Success>>,
      originalExecutor: Executor) {
      switch event {
      case let .update(update):
        let updateToPost: Update? = locking.locker {
          if numberOfFirstToTake > 0 {
            numberOfFirstToTake -= 1
            return update
          } else if numberOfLastToTake > 0 {
            updatesQueue.push(update)
            while updatesQueue.count > numberOfLastToTake {
              _ = updatesQueue.pop()
            }
            return nil
          } else {
            return nil
          }
        }

        if let updateToPost = updateToPost {
          producerBox.value?.update(updateToPost, from: originalExecutor)
        }
      case let .completion(completion):
        if let producer = producerBox.value {
          let queue = locking.locker { updatesQueue }
          producer.update(queue)
          producer.complete(completion, from: originalExecutor)
        }
      }
    }

    return makeProducer(executor: .immediate, pure: true,
                        cancellationToken: cancellationToken,
                        bufferSize: bufferSize, onEvent)
  }
}
