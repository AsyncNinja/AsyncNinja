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

final class LockFreeThreadSafeContainer<Item : AnyObject> : _ThreadSafeContainer {
  fileprivate(set) var head: Item?

  @discardableResult
  func updateHead(_ block: (Item?) -> Item?) -> (oldHead: Item?, newHead: Item?) {
    while true {
      let oldHead = self.head
      let newHead = block(oldHead)
      if compareAndSwap(old: oldHead, new: newHead, to: &self.head) {
        return (oldHead, newHead)
      }
    }
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
