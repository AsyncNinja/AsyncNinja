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

@available(macOS, deprecated: 10.12, message: "Use SpinLockThreadSafeContainer instead")
@available(iOS, deprecated: 10.0, message: "Use SpinLockThreadSafeContainer instead")
@available(tvOS, deprecated: 10.0, message: "Use SpinLockThreadSafeContainer instead")
@available(watchOS, deprecated: 3.0, message: "Use SpinLockThreadSafeContainer instead")
final class SpinLockThreadSafeContainer<Item : AnyObject> : ThreadSafeContainer<Item> {
  private var _lock: OSSpinLock = OS_SPINLOCK_INIT

  @discardableResult
  override func updateHead(_ block: (Item?) -> Item?) -> (oldHead: Item?, newHead: Item?) {
    OSSpinLockLock(&_lock)
    defer { OSSpinLockUnlock(&_lock) }

    let oldHead = self.head
    let newHead = block(oldHead)
    self.head = newHead
    return (oldHead, newHead)
  }
}
