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

import Foundation

typealias MutableFallibleFuture<T> = MutableFuture<Fallible<T>>

public class MutableFuture<T> : Future<T> {
  private var _state: AbstractMutableFutureState<T> = InitialMutableFutureState()

  override func add(handler: FutureHandler<T>) {
    while true {
      if let currentState = _state as? CompletedMutableFutureState<Value> {
        handler.handle(value: currentState.value)
        break
      } else if let currentState = _state as? IncompleteMutableFutureState<Value> {
        let nextState = SubscribedMutableFutureState(handler: handler, nextNode: currentState, owner: self)
        if compareAndSwap(old: currentState, new: nextState, to: &_state) {
          break
        }
      }
    }
  }

  @discardableResult
  final func tryComplete(with value: Value) -> Bool {
    let nextState = CompletedMutableFutureState(value: value)
    while true {
      guard let currentState = _state as? IncompleteMutableFutureState<Value> else { return false }
      guard compareAndSwap(old: currentState, new: nextState, to: &_state) else { continue }

      var handlersNode_ = currentState
      while let handlersNode = handlersNode_ as? SubscribedMutableFutureState<Value> {
        handlersNode.handler.handle(value: value)
        handlersNode_ = handlersNode.nextNode
      }
      return true
    }
  }
}

fileprivate class AbstractMutableFutureState<T> { }

fileprivate class IncompleteMutableFutureState<T> : AbstractMutableFutureState<T> {}

fileprivate class InitialMutableFutureState<T> : IncompleteMutableFutureState<T> {
  typealias Value = T
  typealias Handler = FutureHandler<Value>
}

fileprivate class SubscribedMutableFutureState<T> : IncompleteMutableFutureState<T> {
  typealias Value = T
  typealias Handler = FutureHandler<Value>

  let handler: Handler
  let nextNode: IncompleteMutableFutureState<T>
  let owner: MutableFuture<T>

  init(handler: Handler, nextNode: IncompleteMutableFutureState<T>, owner: MutableFuture<T>) {
    self.handler = handler
    self.nextNode = nextNode
    self.owner = owner
  }
}

fileprivate class CompletedMutableFutureState<T> : AbstractMutableFutureState<T> {
  let value: T

  init(value: T) {
    self.value = value
  }
}

@inline(__always)
fileprivate func compareAndSwap<T: AnyObject>(old: T, new: T, to toPtr: UnsafeMutablePointer<T>) -> Bool {
  let oldRef = Unmanaged.passUnretained(old)
  let newRef = Unmanaged.passRetained(new)
  let oldPtr = oldRef.toOpaque()
  let newPtr = newRef.toOpaque()

  if OSAtomicCompareAndSwapPtrBarrier(UnsafeMutableRawPointer(oldPtr), UnsafeMutableRawPointer(newPtr), UnsafeMutableRawPointer(toPtr).assumingMemoryBound(to: Optional<UnsafeMutableRawPointer>.self)) {
    oldRef.release()
    return true
  } else {
    newRef.release()
    return false
  }
}

@inline(__always)
fileprivate func compareAndSwap<T: AnyObject>(old: T?, new: T?, to toPtr: UnsafeMutablePointer<T?>) -> Bool {
  let oldRef = old.map(Unmanaged.passUnretained)
  let newRef = new.map(Unmanaged.passRetained)
  let oldPtr = oldRef?.toOpaque() ?? nil
  let newPtr = newRef?.toOpaque() ?? nil

  if OSAtomicCompareAndSwapPtrBarrier(UnsafeMutableRawPointer(oldPtr), UnsafeMutableRawPointer(newPtr), UnsafeMutableRawPointer(toPtr).assumingMemoryBound(to: Optional<UnsafeMutableRawPointer>.self)) {
    oldRef?.release()
    return true
  } else {
    newRef?.release()
    return false
  }
}
