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

typealias MutableFallibleFuture<T> = MutableFuture<Fallible<T>>

public class MutableFuture<T> : Future<T>, ThreadSafeContainer {
  typealias ThreadSafeItem = AbstractMutableFutureState<T>
  var head: ThreadSafeItem?
  let releasePool = ReleasePool()

  override func add(handler: FutureHandler<T>) {
    self.updateHead {
      switch $0 {
      case let completedState as CompletedMutableFutureState<Value>:
        handler.handle(value: completedState.value)
        return .keep
      case let incompleteState as SubscribedMutableFutureState<Value>:
        return .replace(SubscribedMutableFutureState(handler: handler, next: incompleteState, owner: self))
      case .none:
        return .replace(SubscribedMutableFutureState(handler: handler, next: nil, owner: self))
      default:
        fatalError()
      }
    }
  }

  @discardableResult
  final func tryComplete(with value: Value) -> Bool {
    let completedItem = CompletedMutableFutureState(value: value)
    let (oldHead, newHead) = self.updateHead { ($0?.isIncomplete ?? true) ? .replace(completedItem) : .keep }
    let didComplete = (completedItem === newHead)
    guard didComplete else { return false }

    var nextItem = oldHead
    while let currentItem = nextItem as? SubscribedMutableFutureState<Value> {
      currentItem.handler?.handle(value: value)
      nextItem = currentItem.next
    }
    self.releasePool.drain()

    return true
  }
}

class AbstractMutableFutureState<T> {
  var isIncomplete: Bool { fatalError() /* abstract */ }
}

final class SubscribedMutableFutureState<T> : AbstractMutableFutureState<T> {
  typealias Value = T
  typealias Handler = FutureHandler<Value>

  weak private(set) var handler: Handler?
  let next: SubscribedMutableFutureState<T>?
  let owner: MutableFuture<T>
  override var isIncomplete: Bool { return true }

  init(handler: Handler, next: SubscribedMutableFutureState<T>?, owner: MutableFuture<T>) {
    self.handler = handler
    self.next = next
    self.owner = owner
  }
}

final class CompletedMutableFutureState<T> : AbstractMutableFutureState<T> {
  let value: T
  override var isIncomplete: Bool { return false }

  init(value: T) {
    self.value = value
  }
}
