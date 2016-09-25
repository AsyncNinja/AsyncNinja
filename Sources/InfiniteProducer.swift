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

final public class InfiniteProducer<PeriodicValue> : InfiniteChannel<PeriodicValue>, MutablePeriodic {
  private let _container = ThreadSafeContainer<SubscribedProducerState<PeriodicValue>>()
  private let releasePool = ReleasePool()

  override public init() { }

  #if os(Linux)
  let sema = DispatchSemaphore(value: 1)
  public func synchronized<T>(_ block: () -> T) -> T {
  self.sema.wait()
  defer { self.sema.signal() }
  return block()
  }
  #endif

  /// **internal use only**
  override public func makePeriodicHandler(executor: Executor,
                                             block: @escaping (PeriodicValue) -> Void) -> InfiniteChannelHandler<PeriodicValue>? {
    let handler = PeriodicHandler(executor: executor, block: block)
    _container.updateHead {
      .replace(SubscribedProducerState(handler: handler, next: $0))
    }
    return handler
  }
  
  final public func send(_ periodic: PeriodicValue) {
    var nextItem = _container.head
    while let currentItem = nextItem {
      currentItem.handler?.handle(periodic)
      nextItem = currentItem.next
    }
  }
  
  final public func send<S: Sequence>(_ periodics: S) where S.Iterator.Element == PeriodicValue {
    var nextItem = _container.head
    while let currentItem = nextItem {
      if let handler = currentItem.handler {
        periodics.forEach(handler.handle)
      }
      nextItem = currentItem.next
    }
  }

  func insertToReleasePool(_ releasable: Releasable) {
    assert((releasable as? AnyObject) !== self) // Xcode 8 mistreats this. This code is valid
    self.releasePool.insert(releasable)
  }

  func notifyDrain(_ block: @escaping () -> Void) {
    self.releasePool.notifyDrain(block)
  }
}

final class SubscribedProducerState<T> {
  typealias Periodic = T
  typealias Handler = InfiniteChannelHandler<Periodic>
  
  weak var handler: Handler?
  let next: SubscribedProducerState<T>?
  
  init(handler: Handler, next: SubscribedProducerState<T>?) {
    self.handler = handler
    self.next = next
  }
}
