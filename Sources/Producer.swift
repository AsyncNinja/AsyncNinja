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

final public class Producer<PeriodicValue, FinalValue> : Channel<PeriodicValue, FinalValue>, MutableFinite, MutablePeriodic {
  public typealias ImmutableFinite = Channel<PeriodicValue, FinalValue>

  typealias RegularState = RegularProducerState<PeriodicValue, FinalValue>
  typealias FinalState = FinalProducerState<PeriodicValue, FinalValue>
  private let releasePool = ReleasePool()
  private var _container = makeThreadSafeContainer()

  override public var finalValue: Fallible<FinalValue>? { return (_container.head as? FinalState)?.final }

  override public init() { }

  /// **internal use only**
  override public func makeHandler(executor: Executor,
                                   block: @escaping (Value) -> Void) -> Handler? {
    let handler = Handler(executor: executor, block: block)
    _container.updateHead {
      switch $0 {
      case .none:
        return RegularState(handler: handler, next: nil)
      case let regularState as RegularState:
        return RegularState(handler: handler, next: regularState)
      case let finalState as FinalState:
        handler.handle(.final(finalState.final))
        return $0
      default:
        fatalError()
      }
    }

    return handler
  }

  @discardableResult
  private func notify(_ value: Value, head: ProducerState<PeriodicValue, FinalValue>?) -> Bool {
    guard let regularState = head as? RegularState else { return false }
    var nextItem: RegularState? = regularState
    
    while let currentItem = nextItem {
      currentItem.handler?.handle(value)
      nextItem = currentItem.next
    }
    return true
  }

  public func apply(_ value: Value) {
    switch value {
    case let .periodic(periodic):
      self.send(periodic)
    case let .final(final):
      self.complete(with: final)
    }
  }

  public func send(_ periodic: PeriodicValue) {
    self.notify(.periodic(periodic), head: _container.head as! ProducerState<PeriodicValue, FinalValue>?)
  }

  public func send<S : Sequence>(_ periodics: S)
    where S.Iterator.Element == PeriodicValue {
      let localHead = _container.head
      for periodic in periodics {
        self.notify(.periodic(periodic), head: localHead as! ProducerState<PeriodicValue, FinalValue>?)
      }
  }
  
  @discardableResult
  public func tryComplete(with final: Fallible<FinalValue>) -> Bool {
    let (oldHead, newHead) = _container.updateHead {
      switch $0 {
      case .none:
        return FinalState(final: final)
      case is RegularState:
        return FinalState(final: final)
      case is FinalState:
        return $0
      default:
        fatalError()
      }
    }
    
    guard nil != newHead else { return false }
    
    return self.notify(.final(final), head: oldHead as! ProducerState<PeriodicValue, FinalValue>?)
  }

  public func insertToReleasePool(_ releasable: Releasable) {
    assert((releasable as? AnyObject) !== self) // Xcode 8 mistreats this. This code is valid
    if !self.isComplete {
      self.releasePool.insert(releasable)
    }
  }

  public func complete(with finite: ImmutableFinite) {
    let handler = finite.makeHandler(executor: .immediate) { [weak self] in
      self?.apply($0)
    }
    
    if let handler = handler {
      self.insertToReleasePool(handler)
    }
  }

  func notifyDrain(_ block: @escaping () -> Void) {
    if self.isComplete {
      block()
    } else {
      self.releasePool.notifyDrain(block)
    }
  }
}

class ProducerState<T, U> {
  typealias Value = ChannelValue<T, U>
  typealias Handler = ChannelHandler<T, U>
  
  init() { }
}

final class RegularProducerState<T, U> : ProducerState<T, U> {
  weak var handler: Handler?
  let next: RegularProducerState<T, U>?
  
  init(handler: Handler, next: RegularProducerState<T, U>?) {
    self.handler = handler
    self.next = next
  }
}

final class FinalProducerState<T, U> : ProducerState<T, U> {
  let final: Fallible<U>
  
  init(final: Fallible<U>) {
    self.final = final
  }
}
