//
//  ThreadSafeContainer.swift
//  FunctionalConcurrency
//
//  Created by Anton Mironov on 09.09.16.
//
//

import Foundation

/// ThreadSafeContainer is a data structure (mixin) that has head and can change this head with thread safety.
/// Current implementation is lock-free that has to be perfect for quick and often updates.
protocol ThreadSafeContainer : class {
  associatedtype ThreadSafeItem: AnyObject
  var head: ThreadSafeItem? { get set }
}

extension ThreadSafeContainer {
  @discardableResult
  func updateHead(_ block: (ThreadSafeItem?) -> HeadChange<ThreadSafeItem>) -> (oldHead: ThreadSafeItem?, newHead: ThreadSafeItem?) {
    while true {
      let localHead = self.head

      switch block(localHead) {
      case .keep:
        return (localHead, localHead)
      case .remove:
        if compareAndSwap(old: localHead, new: nil, to: &self.head) {
          return (localHead, nil)
        }
      case let .replace(newHead):
        if compareAndSwap(old: localHead, new: newHead, to: &self.head) {
          return (localHead, newHead)
        }
      }
    }
  }
}

enum HeadChange<T : AnyObject> {
  case keep
  case remove
  case replace(T)
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
