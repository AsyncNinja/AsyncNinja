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

public class CancellationToken {
  private let _container = ThreadSafeContainer<Item>.make()
  var isCancelled: Bool { return _container.head is CancelledItem }

  public init() { }

  public func notifyCancellation(_ block: @escaping () -> Void) {
    _container.updateHead {
      if let notifyItem = $0 as? NotifyItem {
        return NotifyItem(block: block, next: notifyItem)
      } else {
        return $0
      }
    }
  }

  class Item {
    init() { }
  }

  final class NotifyItem : Item {
    let block: () -> Void
    let next: NotifyItem?

    init(block: @escaping () -> Void, next: NotifyItem?) {
      self.block = block
      self.next = next
    }

    deinit {
      self.block()
    }
  }

  final class CancelledItem : Item { }
  
}
