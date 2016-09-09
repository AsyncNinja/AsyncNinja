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

import Foundation

public class MutableChannel<T> : Channel<T>, ThreadSafeContainer {
  typealias ThreadSafeItem = SubscribedMutableChannelState<T>
  var head: ThreadSafeItem?

  override init() { }

  override func add(handler: Handler) {
    self.updateHead {
      .replace(ThreadSafeItem(handler: handler, next: $0))
    }
  }

  func send(_ value: Value) {
    var nextItem = self.head
    while let currentItem = nextItem {
      currentItem.handler?.handle(value: value)
      nextItem = currentItem.next
    }
  }

  func send<S: Sequence>(_ values: S) where S.Iterator.Element == Value {
    var nextItem = self.head
    while let currentItem = nextItem {
      for value in values {
        currentItem.handler?.handle(value: value)
      }
      nextItem = currentItem.next
    }
  }
}

final class SubscribedMutableChannelState<T> {
  typealias Value = T
  typealias Handler = ChannelHandler<Value>

  weak var handler: Handler?
  let next: SubscribedMutableChannelState<T>?

  init(handler: Handler, next: SubscribedMutableChannelState<T>?) {
    self.handler = handler
    self.next = next
  }
}
