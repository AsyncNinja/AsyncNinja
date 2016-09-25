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

protocol Locking {
  func lock()
  func unlock()
}

func makeLocking() -> Locking {
  #if os(Linux)
    return DispatchSemaphoreLocking()
  #else
    if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
      return UnfairLockLocking()
    } else {
      return SpinLockLocking()
    }
  #endif
}

final class DispatchSemaphoreLocking : Locking {
  private let _sema = DispatchSemaphore(value: 1)

  func lock() {
    _sema.wait()
  }

  func unlock() {
    _sema.signal()
  }
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
@available(macOS, deprecated: 10.12, message: "Use UnfairLockLocking instead")
@available(iOS, deprecated: 10.0, message: "Use UnfairLockLocking instead")
@available(tvOS, deprecated: 10.0, message: "Use UnfairLockLocking instead")
@available(watchOS, deprecated: 3.0, message: "Use UnfairLockLocking instead")
final private class SpinLockLocking : Locking {
  private var _lock: OSSpinLock = OS_SPINLOCK_INIT

  func lock() {
    OSSpinLockLock(&_lock)
  }

  func unlock() {
    OSSpinLockUnlock(&_lock)
  }
}

@available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
final private class UnfairLockLocking : Locking {
  private var _lock = os_unfair_lock_s()

  func lock() {
    os_unfair_lock_lock(&_lock)
  }

  func unlock() {
    os_unfair_lock_unlock(&_lock)
  }
}
#endif
