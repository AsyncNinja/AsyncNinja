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

  private var _container = makeThreadSafeContainer()
  private let _releasePool = ReleasePool()

  /// Returns either completion for complete `Promise` or nil otherwise
  override public var completion: Fallible<Success>? {
    return (_container.head as? CompletedPromiseState)?.value
  }

  /// Designated initializer of promise
  override public init() { }

  /// **internal use only**
  override public func makeCompletionHandler(
    executor: Executor,
    _ block: @escaping (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
    ) -> AnyObject? {
    let handler = PromiseHandler(executor: executor, block: block, owner: self)
    
    _container.updateHead {
      switch $0 {
      case let completedState as CompletedPromiseState<Success>:
        handler.handle(completedState.value, from: nil)
        return $0
      case let incompleteState as SubscribedPromiseState<Success>:
        return SubscribedPromiseState(handler: handler, next: incompleteState)
      case .none:
        return SubscribedPromiseState(handler: handler, next: nil)
      default:
        fatalError()
      }
    }
    
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
    let completedItem = CompletedPromiseState(value: completion)
    let (oldHead, newHead) = _container.updateHead {
      switch $0 {
      case is SubscribedPromiseState<Success>:
        return completedItem
      case let oldCompletedItem as CompletedPromiseState<Success>:
        return oldCompletedItem
      case .none:
        return completedItem
      default:
        fatalError()
      }
    }
    let didComplete = (completedItem === newHead)
    guard didComplete else { return false }

    var nextItem = oldHead
    while let currentItem = nextItem as? SubscribedPromiseState<Success> {
      currentItem.handler?.handle(completion, from: originalExecutor)
      currentItem.releaseOwner()
      nextItem = currentItem.next
    }
    _releasePool.drain()

    return true
  }

  /// **internal use only**
  override public func _asyncNinja_retainUntilFinalization(_ releasable: Releasable) {
    // assert((releasable as? AnyObject) !== self) // Xcode 8 mistreats this. This code is valid
    // assert((releasable as? Handler)?.owner !== self) // This assertion is no longer valid because we have non-contextual on<Event>
    if !self.isComplete {
      _releasePool.insert(releasable)
    }
  }
  
  /// **internal use only**
  override public func _asyncNinja_notifyFinalization(_ block: @escaping () -> Void) {
    if self.isComplete {
      block()
    } else {
      _releasePool.notifyDrain(block)
    }
  }
}

/// **internal use only**
fileprivate class AbstractPromiseState<Success> {
}

/// **internal use only**
fileprivate  class SubscribedPromiseState<Success>: AbstractPromiseState<Success> {
  typealias Value = Fallible<Success>
  typealias Handler = PromiseHandler<Success>
  
  weak private(set) var handler: Handler?
  let next: SubscribedPromiseState<Success>?

  init(handler: Handler, next: SubscribedPromiseState<Success>?) {
    self.handler = handler
    self.next = next
  }

  func releaseOwner() {
    self.handler?.releaseOwner()
  }
}

/// **internal use only**
fileprivate  class CompletedPromiseState<Success>: AbstractPromiseState<Success> {
  let value: Fallible<Success>
  
  init(value: Fallible<Success>) {
    self.value = value
  }
}

/// **Internal use only**
///
/// Each subscription to a future value will be expressed in such handler.
/// Future will accumulate handlers until completion or deallocacion.
final fileprivate class PromiseHandler<Success> {
  typealias Block = (_ completion: Fallible<Success>, _ originalExecutor: Executor) -> Void
  let executor: Executor
  let block: Block
  var owner: Future<Success>?

  init(executor: Executor,
       block: @escaping Block,
       owner: Future<Success>)
  {
    self.executor = executor
    self.block = block
    self.owner = owner
  }

  func handle(_ value: Fallible<Success>, from originalExecutor: Executor?) {
    self.executor.execute(from: originalExecutor) {
      (originalExecutor) in
      self.block(value, originalExecutor)
    }
  }

  func releaseOwner() {
    self.owner = nil
  }
}
