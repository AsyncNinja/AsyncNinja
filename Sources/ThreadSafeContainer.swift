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
