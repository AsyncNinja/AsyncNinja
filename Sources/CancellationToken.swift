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

/// An object that allows to implement and control cancellation
public class CancellationToken {
  private var _container = makeThreadSafeContainer()

  /// Returns state of the object
  public var isCancelled: Bool { return _container.head is CancelledItem }

  /// Designated initializer. Initializes uncancelled token
  public init() { }

  /// Adds block to notify when state changes to cancelled
  /// Specified block will never be called if the token will never be cancelled
  public func notifyCancellation(_ block: @escaping () -> Void) {
    _container.updateHead {
      if let nonCancelledItem = $0 as? NonCancelledItem {
        return NotifyItem(block: block, next: nonCancelledItem)
      } else {
        return $0
      }
    }
  }

  /// Automatically cancelles passed cancellable object on cancellation
  public func add(cancellable: Cancellable) {
    _container.updateHead {
      if let nonCancelledItem = $0 as? NonCancelledItem {
        return ContainerOfCancellableItem(cancellable: cancellable, next: nonCancelledItem)
      } else {
        return $0
      }
    }
  }

  private class Item {
    init() { }
  }

  private class NonCancelledItem: Item {
    let next: NonCancelledItem?

    init(next: NonCancelledItem?) {
      self.next = next
    }
  }

  private class NotifyItem: NonCancelledItem {
    let _block: () -> Void

    init(block: @escaping () -> Void, next: NonCancelledItem?) {
      _block = block
      super.init(next: next)
    }

    deinit {
      _block()
    }
  }

  private class ContainerOfCancellableItem: NonCancelledItem {
    weak var _cancellable: Cancellable?

    init(cancellable: Cancellable, next: NonCancelledItem?) {
      _cancellable = cancellable
      super.init(next: next)
    }

    deinit {
      _cancellable?.cancel()
    }
  }

  private class CancelledItem: Item { }
}

/// Protocol for objects that have cancellation
public protocol Cancellable: class {

  /// Performs cancellation action
  func cancel()
}
