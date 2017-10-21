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
public class CancellationToken: Cancellable {
  public typealias NotifyBlock = () -> Void
  private let _isBackCancelAllowed: Bool
  private var _locking = makeLocking()
  private var _items: [CancellationTokenItem]? = []
  private var _isCancelled: Bool { return self._items.isNone }

  /// Returns state of the object
  public var isCancelled: Bool {
    _locking.lock()
    defer { _locking.unlock() }
    return _isCancelled
  }

  /// Designated initializer
  ///
  /// - Parameter isBackCancelAllowed: true if cancellation of cancellables
  ///   after cancellation of the token is allowed. True by default
  public init(isBackCancelAllowed: Bool = true) {
    _isBackCancelAllowed = isBackCancelAllowed
  }

  private func add(item: CancellationTokenItem) {
    let shouldCancel: Bool
    _locking.lock()
    if _isCancelled {
      shouldCancel = _isBackCancelAllowed
    } else {
      _items?.append(item)
      shouldCancel = false
    }

    _locking.unlock()

    if shouldCancel {
      item.cancel()
    }
  }

  /// Adds block to notify when state changes to cancelled
  /// Specified block will never be called if the token will never be cancelled
  public func notifyCancellation(_ block: @escaping NotifyBlock) {
    add(item: NotifyBlockCancellationTokenItem(block: block))
  }

  /// Automatically cancelles passed cancellable object on cancellation
  public func add(cancellable: Cancellable) {
    add(item: CancellableContainerCancellationTokenItem(cancellable: cancellable))
  }

  /// Manually cancelles all attached items
  public func cancel() {
    let items: [CancellationTokenItem]?
    _locking.lock()
    items = _items
    _items = nil
    _locking.unlock()

    if let items = items {
      for item in items {
        item.cancel()
      }
    }
  }
}

/// Protocol for objects that have cancellation
public protocol Cancellable: class {

  /// Performs cancellation action
  func cancel()
}

private protocol CancellationTokenItem {
  func cancel()
}

private class NotifyBlockCancellationTokenItem: CancellationTokenItem {
  let _block: CancellationToken.NotifyBlock

  init(block: @escaping CancellationToken.NotifyBlock) {
    _block = block
  }

  func cancel() {
    _block()
  }
}

private class CancellableContainerCancellationTokenItem: CancellationTokenItem {
  weak var _cancellable: Cancellable?

  init(cancellable: Cancellable) {
    _cancellable = cancellable
  }

  func cancel() {
    _cancellable?.cancel()
  }
}
