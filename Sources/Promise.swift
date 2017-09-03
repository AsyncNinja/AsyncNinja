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

/// Promise is a future that may be manually completed by owner
final public class Promise<Success>: Future<Success>, Completable, CachableCompletable {
  public typealias CompletingType = Future<Success>

  private var _locking = makeLocking()
  private var _state: AbstractPromiseState<Success>
  private let _releasePool: ReleasePool

  /// Returns either completion for complete `Promise` or nil otherwise
  override public var completion: Fallible<Success>? {
    return _locking.locker(self) { $0._completion }
  }

  private var _completion: Fallible<Success>? {
    return self._state.completion
  }

  private var _isComplete: Bool { return _completion.isSome }

  /// Designated initializer of promise
  override public init() {
    _state = InitialPromiseState(notifyBlock: { _ in })
    _releasePool = ReleasePool(locking: PlaceholderLocking())
    super.init()
  }

  init(notifyBlock: @escaping (_ isCompleted: Bool) -> Void) {
    _state = InitialPromiseState(notifyBlock: notifyBlock)
    _releasePool = ReleasePool(locking: PlaceholderLocking())
  }

  /// **internal use only**
  override public func makeCompletionHandler(
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> AnyObject? {

    let (oldState, handler) = _locking
      .locker(self, executor, block) { (self_, executor, block) -> (AbstractPromiseState<Success>, AnyObject?) in
        let oldState = self_._state
        let (newState, handler) = oldState.subscribe(owner: self_, executor: executor, block)
        self_._state = newState
        return (oldState, handler)
    }

    oldState.didSubscribe(executor: executor, block)

    return handler
  }

  /// Completes promise with value and returns true.
  /// Returns false if promise was completed before.
  ///
  /// - Parameter completion: value to complete future with
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  /// - Returns: true if `Promise` was completed with specified value
  public func tryComplete(
    _ completion: Fallible<Success>,
    from originalExecutor: Executor? = nil
    ) -> Bool {

    let (oldState, handlers) = _locking
      .locker(self, completion) { (self_, completion) -> (AbstractPromiseState<Success>, [PromiseHandler<Success>]?) in
      let oldState = self_._state
      let (newState, handlers) = oldState.complete(completion: completion)
      self_._state = newState
      return (oldState, handlers)
    }

    oldState.didComplete(completion, from: originalExecutor)

    guard let handlers_ = handlers else {
      return false
    }

    for handler in handlers_ {
      handler.handle(completion, from: originalExecutor)
    }

    // it is not safe to use release pool outside critical section.
    // But at this point we have a guarantee that nobody else will use it
    _releasePool.drain()
    return true
  }

  /// **internal use only**
  override public func _asyncNinja_retainUntilFinalization(_ releasable: Releasable) {
    _locking.locker(self, releasable) { (self_, releasable) -> Void in
      if !self_._isComplete {
        self_._releasePool.insert(releasable)
      }
    }
  }

  /// **internal use only**
  override public func _asyncNinja_notifyFinalization(_ block: @escaping () -> Void) {
    let shouldCallBlockNow = _locking.locker(self, block) { (self_, block) -> Bool in
      if self_._isComplete {
        return true
      } else {
        self_._releasePool.notifyDrain(block)
        return false
      }
    }

    if shouldCallBlockNow {
      block()
    }
  }
}

/// **internal use only**
private class AbstractPromiseState<Success> {
  var completion: Fallible<Success>? { return nil }

  func subscribe(
    owner: Future<Success>,
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> (AbstractPromiseState<Success>, PromiseHandler<Success>?) {
    return (self, nil)
  }

  func didSubscribe(
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>,
    _ originalExecutor: Executor) -> Void) {
  }

  func complete(completion: Fallible<Success>) -> (AbstractPromiseState<Success>, [PromiseHandler<Success>]?) {
    fatalError()
  }

  func didComplete(_ value: Fallible<Success>, from originalExecutor: Executor?) {
  }
}

private class InitialPromiseState<Success>: AbstractPromiseState<Success> {
  let notifyBlock: (_ isCompleted: Bool) -> Void
  init(notifyBlock: @escaping (_ isCompleted: Bool) -> Void) {
    self.notifyBlock = notifyBlock
  }

  override func subscribe(
    owner: Future<Success>,
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> (AbstractPromiseState<Success>, PromiseHandler<Success>?) {
    let handler = PromiseHandler(executor: executor, block: block, owner: owner)
    return (SubscribedPromiseState(firstHandler: handler), handler)
  }

  override func didSubscribe(
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>,
    _ originalExecutor: Executor) -> Void) {
    notifyBlock(false)
  }

  override func complete(completion: Fallible<Success>) -> (AbstractPromiseState<Success>, [PromiseHandler<Success>]?) {
    return (CompletedPromiseState<Success>(completion: completion), [])
  }

  override func didComplete(_ value: Fallible<Success>, from originalExecutor: Executor?) {
    notifyBlock(true)
  }
}

/// **internal use only**
private class SubscribedPromiseState<Success>: AbstractPromiseState<Success> {
  var handlers: [WeakBox<PromiseHandler<Success>>]

  init(firstHandler: PromiseHandler<Success>) {
    self.handlers = [WeakBox(firstHandler)]
  }

  override func subscribe(
    owner: Future<Success>,
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> (AbstractPromiseState<Success>, PromiseHandler<Success>?) {
    let handler = PromiseHandler(executor: executor, block: block, owner: owner)
    handlers.append(WeakBox(handler))
    return (self, handler)
  }

  override func complete(completion: Fallible<Success>) -> (AbstractPromiseState<Success>, [PromiseHandler<Success>]?) {
    let unwrappedHandlers = handlers.flatMap { $0.value }
    handlers = []
    return (CompletedPromiseState<Success>(completion: completion), unwrappedHandlers)
  }
}

/// **internal use only**
private class CompletedPromiseState<Success>: AbstractPromiseState<Success> {
  override var completion: Fallible<Success>? { return _completion }
  let _completion: Fallible<Success>

  init(completion: Fallible<Success>) {
    _completion = completion
  }

  override func subscribe(
    owner: Future<Success>,
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> (AbstractPromiseState<Success>, PromiseHandler<Success>?) {
    return (self, nil)
  }

  override func didSubscribe(
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void) {
    let localCompletion = _completion
    executor.execute(from: nil) { (originalExecutor) in
      block(localCompletion, originalExecutor)
    }
  }

  override func complete(completion: Fallible<Success>) -> (AbstractPromiseState<Success>, [PromiseHandler<Success>]?) {
    return (self, nil)
  }
}

/// **Internal use only**
///
/// Each subscription to a future value will be expressed in such handler.
/// Future will accumulate handlers until completion or deallocacion.
final private class PromiseHandler<Success> {
  typealias Block = (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
  let executor: Executor
  let block: Block
  var owner: Future<Success>?

  init(executor: Executor,
       block: @escaping Block,
       owner: Future<Success>) {
    self.executor = executor
    self.block = block
    self.owner = owner
  }

  func handle(_ value: Fallible<Success>, from originalExecutor: Executor?) {
    let localBlock = block
    executor.execute(from: originalExecutor) { (originalExecutor) in
      localBlock(value, originalExecutor)
    }
    owner = nil
  }
}
