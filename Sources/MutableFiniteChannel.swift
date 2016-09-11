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

public class MutableFiniteChannel<T, U> : FiniteChannel<T, U>, ThreadSafeContainer {

  typealias ThreadSafeItem = MutableFiniteChannelState<RegularValue, FinalValue>
  typealias RegularState = RegularMutableFiniteChannelState<RegularValue, FinalValue>
  typealias FinalState = FinalMutableFiniteChannelState<RegularValue, FinalValue>
  var head: ThreadSafeItem?

  override init() { }

  override public func add(handler: Handler) {
    self.updateHead {
      switch $0 {
      case .none:
        return .replace(RegularState(handler: handler, next: nil))
      case let regularState as RegularState:
        return .replace(RegularState(handler: handler, next: regularState))
      case let finalState as FinalState:
        handler.handle(value: .final(finalState.finalValue))
        return .keep
      default:
        fatalError()
      }
    }
  }

  private func notify(_ value: Value, head: ThreadSafeItem?) -> Bool {
    guard let regularState = head as? RegularState else { return false }
    var nextItem: RegularState? = regularState

    while let currentItem = nextItem {
      currentItem.handler?.handle(value: value)
      nextItem = currentItem.next
    }
    return true
  }

  func send(regular regularValue: RegularValue) -> Bool {
    return self.notify(.regular(regularValue), head: self.head)
  }

  func send(final finalValue: FinalValue) -> Bool {
    let (oldHead, newHead) = self.updateHead {
      switch $0 {
      case .none:
        return .replace(FinalState(finalValue: finalValue))
      case is RegularState:
        return .replace(FinalState(finalValue: finalValue))
      case is FinalState:
        return .keep
      default:
        fatalError()
      }
    }

    guard nil != newHead else { return false }

    return self.notify(.final(finalValue), head: oldHead)
  }
}

class MutableFiniteChannelState<T, U> {
  typealias Value = FiniteChannelValue<T, U>
  typealias Handler = FiniteChannelHandler<T, U>

  init() { }
}

final class RegularMutableFiniteChannelState<T, U> : MutableFiniteChannelState<T, U> {
  weak var handler: Handler?
  let next: RegularMutableFiniteChannelState<T, U>?

  init(handler: Handler, next: RegularMutableFiniteChannelState<T, U>?) {
    self.handler = handler
    self.next = next
  }
}

final class FinalMutableFiniteChannelState<T, U> : MutableFiniteChannelState<T, U> {
  let finalValue: U

  init(finalValue: U) {
    self.finalValue = finalValue
  }
}
