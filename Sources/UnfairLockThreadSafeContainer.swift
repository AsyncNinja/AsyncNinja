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

@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
final class UnfairLockThreadSafeContainer<Item : AnyObject> : ThreadSafeContainer<Item> {
  private var _lock = os_unfair_lock_s()

  @discardableResult
  override func updateHead(_ block: (Item?) -> Item?) -> (oldHead: Item?, newHead: Item?) {
    os_unfair_lock_lock(&_lock)
    defer { os_unfair_lock_unlock(&_lock) }

    let oldHead = self.head
    let newHead = block(oldHead)
    self.head = newHead
    return (oldHead, newHead)
  }
}
