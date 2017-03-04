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

/// represents values that updateally arrive followed by failure of completion that completes Channel. Channel oftenly represents result of long running task that is not yet arrived and flow of some intermediate results.
public class Channel<U, S>: Streaming, Sequence {
  public typealias Update = U
  public typealias Success = S
  public typealias Handler = ChannelHandler<Update, Success>
  public typealias Iterator = ChannelIterator<Update, Success>

  /// completion of channel. Returns nil if channel is not complete yet
  public var completion: Fallible<Success>? { assertAbstract() }

  /// amount of currently stored updates
  public var bufferSize: Int { assertAbstract() }

  /// maximal amount of updates store
  public var maxBufferSize: Int { assertAbstract() }

  init() { }

  /// **internal use only**
  public func makeHandler(
    executor: Executor,
    _ block: @escaping (_ event: Event, _ originalExecutor: Executor) -> Void) -> AnyObject? {
    assertAbstract()
  }

  /// Makes an iterator that allows synchronous iteration over update values of the channel
  public func makeIterator() -> Iterator {
    assertAbstract()
  }
  
  /// **Internal use only**.
  public func insertToReleasePool(_ releasable: Releasable) {
    assertAbstract()
  }
}

// MARK: - Description

extension Channel: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of this instance.
  public var description: String {
    return description(withBody: "Channel")
  }

  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    return description(withBody: "Channel<\(Update.self), \(Success.self)>")
  }

  /// **internal use only**
  private func description(withBody body: String) -> String {
    switch completion {
    case .some(.success(let value)):
      return "Succeded(\(value)) \(body)"
    case .some(.failure(let error)):
      return "Failed(\(error)) \(body)"
    case .none:
      let currentBufferSize = self.bufferSize
      let maxBufferSize = self.maxBufferSize
      let bufferedString = (0 == maxBufferSize)
        ? ""
        : " Buffered(\(currentBufferSize)/\(maxBufferSize))"
      return "Incomplete\(bufferedString) \(body)"
    }
  }
}

// MARK: - Subscriptions

public extension Channel {
  /// Synchronously waits for channel to complete. Returns all updates and completion
  func waitForAll() -> (updates: [Update], completion: Fallible<Success>) {
    return (self.map { $0 }, self.completion!)
  }
}

// MARK: - Iterators

/// Synchronously iterates over each update value of channel
public struct ChannelIterator<Update, Success>: IteratorProtocol  {
  public typealias Element = Update
  private var _implBox: Box<ChannelIteratorImpl<Update, Success>> // want to have reference to reference, because impl may actually be retained by some handler

  /// completion of the channel. Will be available as soon as the channel completes.
  public var completion: Fallible<Success>? { return _implBox.value.completion }

  /// success of the channel. Will be available as soon as the channel completes with success.
  public var success: Success? { return _implBox.value.completion?.success }
  
  /// failure of the channel. Will be available as soon as the channel completes with failure.
  public var filure: Swift.Error? { return _implBox.value.completion?.failure }

  /// **internal use only** Designated initializer
  init(impl: ChannelIteratorImpl<Update, Success>) {
    _implBox = Box(impl)
  }

  /// fetches next value from the channel.
  /// Waits for the next value to appear.
  /// Returns nil when then channel completes
  public mutating func next() -> Update? {
    if !isKnownUniquelyReferenced(&_implBox) {
      _implBox = Box(_implBox.value.clone())
    }
    return _implBox.value.next()
  }
}

/// **Internal use only**
class ChannelIteratorImpl<Update, Success>  {
  public typealias Element = Update
  var completion: Fallible<Success>? { assertAbstract() }

  init() { }

  public func next() -> Update? {
    assertAbstract()
  }

  func clone() -> ChannelIteratorImpl<Update, Success> {
    assertAbstract()
  }
}

// MARK: - Handlers

/// **internal use only** Wraps each block submitted to the channel
/// to provide required memory management behavior
final public class ChannelHandler<Update, Success> {
  public typealias Event = ChannelEvent<Update, Success>
  typealias Block = (_ event: Event, _ on: Executor) -> Void

  let executor: Executor
  let block: Block
  var locking = makeLocking()
  var bufferedUpdates: Queue<Update>?
  var owner: Channel<Update, Success>?

  /// Designated initializer of ChannelHandler
  init(executor: Executor,
       bufferedUpdates: Queue<Update>,
       owner: Channel<Update, Success>,
       block: @escaping Block) {
    self.executor = executor
    self.block = block
    self.bufferedUpdates = bufferedUpdates
    self.owner = owner

    executor.execute(from: nil) { (originalExecutor) in
      self.handleBufferedUpdatesIfNeeded(from: originalExecutor)
    }
  }

  func handleBufferedUpdatesIfNeeded(from originalExecutor: Executor) {
    locking.lock()
    let bufferedUpdates = self.bufferedUpdates
    self.bufferedUpdates = nil
    locking.unlock()

    if let bufferedUpdates = bufferedUpdates {
      for update in bufferedUpdates {
        handle(.update(update), from: originalExecutor)
      }
    }
  }

  func handle(_ value: Event, from originalExecutor: Executor?) {
    self.executor.execute(from: originalExecutor) {
      (originalExecutor) in
      self.handleBufferedUpdatesIfNeeded(from: originalExecutor)
      self.block(value, originalExecutor)
    }
  }

  func releaseOwner() {
    self.owner = nil
  }
}
