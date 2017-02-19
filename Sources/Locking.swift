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

protocol Locking {
  mutating func lock()
  mutating func unlock()
}

extension Locking {
  mutating func locker<T>(_ locked: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try locked()
  }

  mutating func locker(_ locked: () -> Void) -> Void {
    lock()
    locked()
    unlock()
  }
}

func makeLocking(isFair: Bool = false) -> Locking {
  #if os(Linux)
    return DispatchSemaphore(value: 1)
  #else
    if isFair {
      return DispatchSemaphore(value: 1)
    } else if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
      return UnfairLockLocking()
    } else {
      return SpinLockLocking()
    }
  #endif
}

extension DispatchSemaphore: Locking {
  func lock() {
    self.wait()
  }

  func unlock() {
    self.signal()
  }
}

class PlaceholderLocking: Locking {
  func lock() { }
  func unlock() { }
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
@available(macOS, deprecated: 10.12, message: "Use UnfairLockLocking instead")
@available(iOS, deprecated: 10.0, message: "Use UnfairLockLocking instead")
@available(tvOS, deprecated: 10.0, message: "Use UnfairLockLocking instead")
@available(watchOS, deprecated: 3.0, message: "Use UnfairLockLocking instead")
struct SpinLockLocking: Locking {
  private var _lock: OSSpinLock = OS_SPINLOCK_INIT

  mutating func lock() {
    OSSpinLockLock(&_lock)
  }

  mutating func unlock() {
    OSSpinLockUnlock(&_lock)
  }
}

@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
struct  UnfairLockLocking: Locking {
  private var _lock = os_unfair_lock_s()

  mutating func lock() {
    os_unfair_lock_lock(&_lock)
  }

  mutating func unlock() {
    os_unfair_lock_unlock(&_lock)
  }
}
#endif
