//
//  Copyright (c) 2016 Anton Mironov
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

/// Promise that may be manually completed by owner.
final public class Promise<T> : Future<T>, ThreadSafeContainer {
  typealias ThreadSafeItem = AbstractPromiseState<T>
  var head: ThreadSafeItem?
  let releasePool = ReleasePool()

  override public init() { }

  /// **internal use only**
  override public func makeFinalHandler(executor: Executor, block: @escaping (FinalValue) -> Void) -> FutureHandler<T>? {
    let handler = Handler(executor: executor, block: block, owner: self)
    self.updateHead {
      switch $0 {
      case let completedState as CompletedPromiseState<Value>:
        handler.handle(completedState.value)
        return .keep
      case let incompleteState as SubscribedPromiseState<Value>:
        return .replace(SubscribedPromiseState(handler: handler, next: incompleteState, owner: self))
      case .none:
        return .replace(SubscribedPromiseState(handler: handler, next: nil, owner: self))
      default:
        fatalError()
      }
    }
    return handler
  }

  /// Completes promise with value and returns true.
  /// Returns false if promise was completed before.
  @discardableResult
  final public func complete(with final: Value) -> Bool {
    let completedItem = CompletedPromiseState(value: final)
    let (oldHead, newHead) = self.updateHead { ($0?.isIncomplete ?? true) ? .replace(completedItem) : .keep }
    let didComplete = (completedItem === newHead)
    guard didComplete else { return false }
    
    var nextItem = oldHead
    while let currentItem = nextItem as? SubscribedPromiseState<Value> {
      currentItem.handler?.handle(final)
      nextItem = currentItem.next
    }
    self.releasePool.drain()
    
    return true
  }

  /// Completes promise when specified future completes.
  /// `self` will retain specified future until it`s completion
  @discardableResult
  final public func complete(with future: Future<Value>) {
    let handler = future.makeFinalHandler(executor: .immediate) { [weak self] in
      self?.complete(with: $0)
    }
    self.releasePool.insert(handler)
  }
}

/// **internal use only**
class AbstractPromiseState<T> {
  var isIncomplete: Bool { fatalError() /* abstract */ }
}

/// **internal use only**
final class SubscribedPromiseState<T> : AbstractPromiseState<T> {
  typealias Value = T
  typealias Handler = FutureHandler<Value>
  
  weak private(set) var handler: Handler?
  let next: SubscribedPromiseState<T>?
  let owner: Promise<T>
  override var isIncomplete: Bool { return true }
  
  init(handler: Handler, next: SubscribedPromiseState<T>?, owner: Promise<T>) {
    self.handler = handler
    self.next = next
    self.owner = owner
  }
}

/// **internal use only**
final class CompletedPromiseState<T> : AbstractPromiseState<T> {
  let value: T
  override var isIncomplete: Bool { return false }
  
  init(value: T) {
    self.value = value
  }
}
