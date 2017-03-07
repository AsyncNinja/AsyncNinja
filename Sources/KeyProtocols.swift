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

// MARK: - Completion

public protocol CompletionController: LifetimeExtender {
  associatedtype Success
}

/// A protocol for objects that can eventually complete with value
public protocol Completing: CompletionController {
  /// Returns either completion value for complete `Completing` or nil otherwise
  var completion: Fallible<Success>? { get }

  /// **internal use only**
  func makeCompletionHandler(
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> AnyObject?
}

/// A protocol for objects that can be manually completed
public protocol Completable: CompletionController, Cancellable {

  /// Completes `Completing` with value and returns true.
  /// Returns false if promise was completed before.
  ///
  /// - Parameter completion: value to compete `Completing` with
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  /// - Returns: true if this call completed `Completable`
  @discardableResult
  func tryComplete(_ completion: Fallible<Success>, from originalExecutor: Executor?) -> Bool
}

// MARK: - Updates

public protocol UpdatesController: LifetimeExtender {
  associatedtype Update
}

public protocol Updating: UpdatesController {

  /// **internal use only**
  func makeUpdateHandler(
    executor: Executor,
    _ block: @escaping (_ update: Update, _ originalExecutor: Executor) -> Void
    ) -> AnyObject?
}

public extension Updating {
  /// Subscribes for buffered and new update values for the channel
  ///
  /// - Parameters:
  ///   - executor: to execute block on
  ///   - block: to execute. Will be called multiple times
  ///   - update: received by the channel
  func onUpdate(
    executor: Executor = .primary,
    _ block: @escaping (_ update: Update) -> Void) {
    let handler = self.makeUpdateHandler(executor: executor) {
      (update, originalExecutor) in
      block(update)
    }
    self._asyncNinja_retainHandlerUntilFinalization(handler)
  }

  /// Subscribes for buffered and new update values for the channel
  ///
  /// - Parameters:
  ///   - context: `ExectionContext` to apply transformation in
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need
  ///     to override an executor provided by the context
  ///   - block: to execute. Will be called multiple times
  ///   - strongContext: context restored from weak reference to specified context
  ///   - update: received by the channel
  func onUpdate<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ block: @escaping (_ strongContext: C, _ update: Update) -> Void) {
    let handler = self.makeUpdateHandler(executor: executor ?? context.executor)
    {
      [weak context] (update, originalExecutor) in
      guard let context = context else { return }
      block(context, update)
    }
    self._asyncNinja_retainHandlerUntilFinalization(handler)
  }
}

public protocol Updatable: UpdatesController {

  /// Sends specified Update to the Updatable
  ///
  /// - Parameter update: value to update with
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  func update(_ update: Update,
              from originalExecutor: Executor?)
}

// MARK: - Events
public protocol EventsController: UpdatesController, CompletionController {
}

public extension EventsController {
  typealias Event = ChannelEvent<Update, Success>
}

public protocol EventsSource: EventsController, Completing, Updating, Sequence {

  associatedtype Iterator: IteratorProtocol = ChannelIterator<Update, Success>

  /// amount of currently stored updates
  var bufferSize: Int { get }

  /// maximal amount of updates store
  var maxBufferSize: Int { get }

  /// **internal use only**
  func makeHandler(
    executor: Executor,
    _ block: @escaping (_ event: Event, _ originalExecutor: Executor) -> Void) -> AnyObject?
}

public protocol EventsDestination: EventsController, Updatable, Completable {
}

public extension EventsDestination {

  /// Applies specified ChannelValue to the Producer
  /// Value will not be applied for completed Producer
  ///
  /// - Parameter event: `Event` to apply.
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  public func apply(_ event: ChannelEvent<Update, Success>,
                    from originalExecutor: Executor? = nil) {
    switch event {
    case let .update(update):
      self.update(update, from: originalExecutor)
    case let .completion(completion):
      self.complete(completion, from: originalExecutor)
    }
  }
}

// MARK: - Supporting Interfaces

public protocol LifetimeExtender: class {
  /// **Internal use only**.
  func _asyncNinja_retainUntilFinalization(_ releasable: Releasable)

  /// **Internal use only**. Specified block will be called on completion, but will not keep self alive.
  func _asyncNinja_notifyFinalization(_ block: @escaping () -> Void)
}

public extension LifetimeExtender {
  /// **internal use only**
  func _asyncNinja_retainHandlerUntilFinalization(_ handler: AnyObject?) {
    if let handler = handler {
      _asyncNinja_retainUntilFinalization(handler)
    }
  }
}

/// Value reveived by channel
public enum ChannelEvent<Update, Success> {
  /// A kind of value that can be received multiple times be for the completion one
  case update(Update)

  /// A kind of value that can be received once and completes the channel
  case completion(Fallible<Success>)
}
