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

func makeThreadSafeContainer() -> ThreadSafeContainer {
  #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    if AsyncNinjaConstants.isLockFreeUseAllowed {
      return LockFreeThreadSafeContainer()
    } else {
      return LockingThreadSafeContainer(locking: makeLocking())
    }
  #else
    return LockingThreadSafeContainer(locking: makeLocking())
  #endif
}

/// ThreadSafeContainer is a data structure that has head and can change this head with thread safety.
protocol ThreadSafeContainer {
  var head: AnyObject? { get }

  @discardableResult
  mutating func updateHead(_ block: (AnyObject?) -> AnyObject?) -> (oldHead: AnyObject?, newHead: AnyObject?)
}

private struct LockingThreadSafeContainer : ThreadSafeContainer {
  private var _locking: Locking
  var head: AnyObject?

  init(locking: Locking) {
    _locking = locking
  }

  @discardableResult
  mutating func updateHead(_ block: (AnyObject?) -> AnyObject?) -> (oldHead: AnyObject?, newHead: AnyObject?) {
    _locking.lock()
    defer { _locking.unlock() }

    let oldHead = self.head
    let newHead = block(oldHead)
    self.head = newHead
    return (oldHead, newHead)
  }
}
