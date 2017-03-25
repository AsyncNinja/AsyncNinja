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

/// Context indepedent locking. Non-recursive.
public protocol Locking {

  /// Locks. Be sure to balance with unlock
  mutating func lock()

  /// Unlocks. Be sure to balance with lock
  mutating func unlock()
}

public extension Locking {

  /// Locks and performs block
  ///
  /// - Parameter locked: locked function to perform
  /// - Returns: value returned by the locker
  mutating func locker<T>(_ locked: () throws -> T) rethrows -> T {
    lock()
    defer { unlock() }
    return try locked()
  }

  /// Locks and performs block
  ///
  /// - Parameter locked: locked function to perform
  mutating func locker(_ locked: () -> Void) -> Void {
    lock()
    locked()
    unlock()
  }
}

/// Makes a platform independent Locking
///
/// - Parameter isFair: determines if locking is fair
/// - Returns: constructed Locking
public func makeLocking(isFair: Bool = false) -> Locking {
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

  /// Locks. Be sure to balance with unlock
  public func lock() {
    self.wait()
  }

  /// Unlocks. Be sure to balance with lock
  public func unlock() {
    self.signal()
  }
}

/// **internal use only** Behaves like a locking but actually does nothing.
struct PlaceholderLocking: Locking {
  mutating func lock() { }
  mutating func unlock() { }
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
/// **internal use only**
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

/// **internal use only**
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
