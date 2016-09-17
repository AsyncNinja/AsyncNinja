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

public class CancellationToken : ThreadSafeContainer {
  typealias ThreadSafeItem = CancellationTokenItem

  var head: ThreadSafeItem? = nil
  var isCancelled: Bool { return self.head is CancelledCancellationTokenItem }

  public init() { }

  #if os(Linux)
  let sema = DispatchSemaphore(value: 1)
  public func synchronized<T>(_ block: () -> T) -> T {
  self.sema.wait()
  defer { self.sema.signal() }
  return block()
  }
  #endif

  public func notifyCancellation(_ block: @escaping () -> Void) {
    self.updateHead {
      if let notifyItem = $0 as? NotifyCancellationTokenItem {
        return .replace(NotifyCancellationTokenItem(block: block, next: notifyItem))
      } else {
        return .keep
      }
    }
  }
}

class CancellationTokenItem {
  init() { }
}

final class NotifyCancellationTokenItem : CancellationTokenItem {
  let block: () -> Void
  let next: NotifyCancellationTokenItem?

  init(block: @escaping () -> Void, next: NotifyCancellationTokenItem?) {
    self.block = block
    self.next = next
  }

  deinit {
    self.block()
  }
}

final class CancelledCancellationTokenItem : CancellationTokenItem { }
