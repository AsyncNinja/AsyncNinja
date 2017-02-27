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

public typealias Releasable = Any

/// ReleasePool is an object that retains another objects
public class ReleasePool {
  var _locking: Locking
  var _objectsContainer = [Releasable]()
  var _blocksContainer = [() -> Void]()

  /// Designated initializer of ReleasePool
  public init() {
    _locking = makeLocking()
  }

  init(locking: Locking) {
    _locking = locking
  }

  deinit {
    drain()
  }

  /// Inserts object to retain
  public func insert(_ releasable: Releasable) {
    _locking.lock()
    defer { _locking.unlock() }
    _objectsContainer.append(releasable)
  }

  /// Adds block to call on draining ReleasePool
  ///
  /// - Parameter block: to call
  public func notifyDrain(_ block: @escaping () -> Void) {
    _locking.lock()
    defer { _locking.unlock() }
    _blocksContainer.append(block)
  }

  /// Causes release of all retained objects
  public func drain() {
    _locking.lock()
    _objectsContainer.removeAll()
    let blocksContainer = _blocksContainer
    _blocksContainer.removeAll()
    _locking.unlock()
    for block in blocksContainer {
      block()
    }
  }
}
