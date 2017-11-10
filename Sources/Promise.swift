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
  private var _state: PromiseState<Success>
  private var _objectsContainer = [Releasable]()
  private var _blocksContainer = [() -> Void]()

  /// Returns either completion for complete `Promise` or nil otherwise
  override public var completion: Fallible<Success>? {
    _locking.lock()
    defer { _locking.unlock() }
    if case .completed(let completion) = _state {
      return completion
    } else {
      return nil
    }
  }

  /// Designated initializer of promise
  override public init() {
    _state = .initialNoBlock
    super.init()
  }

  init(notifyBlock: @escaping (_ isCompleted: Bool) -> Void) {
    _state = .initial(notifyBlock: notifyBlock)
  }

  deinit {
    for block in _blocksContainer {
      block()
    }
  }

  /// **internal use only**
  override public func makeCompletionHandler(
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> AnyObject? {

    _locking.lock()
    let oldState = _state
    let (newState, handler) = oldState.subscribe(owner: self, executor: executor, block)
    _state = newState
    _locking.unlock()

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

    var blocksContainer: [() -> Void] = []
    var objectContainer: [Releasable] = []
    var handlers: [PromiseHandler<Success>] = []

    _locking.lock()

    let oldState = _state
    let (newState, completionResult) = oldState.complete(completion: completion)
    let didComplete: Bool
    _state = newState
    switch completionResult {
    case .completeEmpty:
      swap(&objectContainer, &_objectsContainer)
      swap(&blocksContainer, &_blocksContainer)
      didComplete = true
    case .complete(let handlers_):
      swap(&objectContainer, &_objectsContainer)
      swap(&blocksContainer, &_blocksContainer)
      handlers = handlers_
      didComplete = true
    case .overcomplete:
      didComplete = false
    }

    _locking.unlock()

    oldState.didComplete(completion, from: originalExecutor)

    for handler in handlers {
      handler.handle(completion, from: originalExecutor)
    }

    objectContainer = []

    for block in blocksContainer {
      block()
    }

    return didComplete
  }

  /// **internal use only**
  override public func _asyncNinja_retainUntilFinalization(_ releasable: Releasable) {
    _locking.lock()
    if case .completed = _state {
      // do nothing
    } else {
      _objectsContainer.append(releasable)
    }
    _locking.unlock()
  }

  /// **internal use only**
  override public func _asyncNinja_notifyFinalization(_ block: @escaping () -> Void) {
    let shouldCallBlockNow: Bool
    _locking.lock()
    if case .completed = _state {
      shouldCallBlockNow = true
    } else {
      _blocksContainer.append(block)
      shouldCallBlockNow = false
    }
    _locking.unlock()

    if shouldCallBlockNow {
      block()
    }
  }
}

/// **internal use only**
private enum PromiseStateCompletionResult<Success> {
  case completeEmpty
  case complete([PromiseHandler<Success>])
  case overcomplete
}

/// **internal use only**
private enum PromiseState<Success> {
  case initialNoBlock
  case initial(notifyBlock: (_ isCompleted: Bool) -> Void)

  // mutable box to prevent unexpected copy on write
  case subscribed(handlers: MutableBox<[WeakBox<PromiseHandler<Success>>]>)
  case completed(completion: Fallible<Success>)

  func subscribe(
    owner: Future<Success>,
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> (PromiseState<Success>, PromiseHandler<Success>?) {
    switch self {
    case .initialNoBlock, .initial:
      let handler = PromiseHandler(executor: executor, block: block, owner: owner)
      let handlers = [WeakBox(handler)]
      return (.subscribed(handlers: MutableBox(handlers)), handler)
    case let .subscribed(handlers):
      let handler = PromiseHandler(executor: executor, block: block, owner: owner)
      handlers.value.append(WeakBox(handler))
      return (self, handler)
    case .completed:
      return (self, nil)
    }
  }

  func didSubscribe(
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>,
    _ originalExecutor: Executor) -> Void) {
    switch self {
    case .initialNoBlock:
      break
    case let .initial(notifyBlock):
      notifyBlock(false)
    case .subscribed:
      break
    case let .completed(completion):
      executor.execute(from: nil, value: completion, block)
    }
  }

  func complete(completion: Fallible<Success>) -> (PromiseState<Success>, PromiseStateCompletionResult<Success>) {
    switch self {
    case .initialNoBlock:
      return (.completed(completion: completion), .completeEmpty)
    case .initial:
      return (.completed(completion: completion), .completeEmpty)
    case let .subscribed(handlers):
      let unwrappedHandlers = handlers.value.flatMap { $0.value }
      return (.completed(completion: completion), .complete(unwrappedHandlers))
    case .completed:
      return (self, .overcomplete)
    }
  }

  func didComplete(_ value: Fallible<Success>, from originalExecutor: Executor?) {
    switch self {
    case .initialNoBlock:
      break
    case let .initial(notifyBlock):
      notifyBlock(true)
    case .subscribed:
      break
    case .completed:
      break
    }
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

  func handle(_ completion: Fallible<Success>, from originalExecutor: Executor?) {
    executor.execute(from: originalExecutor, value: completion, block)
    owner = nil
  }
}
