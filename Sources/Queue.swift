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

typealias Queue<Element> = QueueImpl<QueueStrongElementWrapper<Element>>
typealias QueueOfWeakElements<Element: AnyObject> = QueueImpl<QueueWeakElementWrapper<Element>>

class QueueImpl<Wrapper: QueueElementWrapper> {
  typealias Iterator = QueueIterator<Wrapper>
  typealias Element = Wrapper.Element

  private var _first: Wrapper? = nil
  private var _last: Wrapper? = nil
  private(set) var count = 0
  var first: Element? { return _first?.element }
  var last: Element? { return _last?.element }
  var isEmpty: Bool { return nil == _first }

  init() { }

  func makeIterator() -> Iterator {
    return Iterator(queueElementWrapper: _first)
  }

  func push(_ element: Element) {
    let new = Wrapper(element: element)
    if let last = _last {
      last.next = new
    } else {
      _first = new
    }
    _last = new
    self.count += 1
  }

  func pop() -> Element? {
    guard let first = _first else { return nil }
    if let next = first.next {
      _first = next
    } else {
      _first = nil
      _last = nil
    }

    self.count -= 1
    return first.element
  }

  func removeAll() {
    _first = nil
    _last = nil
  }

  func clone() -> QueueImpl<Wrapper> {
    let result = QueueImpl<Wrapper>()
    var iterator = self.makeIterator()
    while let value = iterator.next() {
      result.push(value)
    }
    return result
  }

  func forEach(andReset: Bool = false, _ block: (Wrapper.Element) -> Void) {
    var wrapper_ = _first
    if andReset {
      _first = nil
      _last = nil
    }
    while let wrapper = wrapper_ {
      if let element = wrapper.element {
        block(element)
      }
      wrapper_ = wrapper.next
    }
  }
}

protocol QueueElementWrapper: class {
  associatedtype Element

  var element: Element? { get }
  var next: Self? { get set }

  init(element: Element)
}

final class QueueStrongElementWrapper<Element>: QueueElementWrapper {
  let element: Element?
  var next: QueueStrongElementWrapper<Element>?

  required init(element: Element) {
    self.element = element
  }
}

final class QueueWeakElementWrapper<Element: AnyObject>: QueueElementWrapper {
  private weak var _element: Element?
  var element: Element? { return _element }
  var next: QueueWeakElementWrapper<Element>?

  required init(element: Element) {
    _element = element
  }
}

struct QueueIterator<Wrapper: QueueElementWrapper>: IteratorProtocol {
  private var _queueElementWrapper: Wrapper?

  init(queueElementWrapper: Wrapper?) {
    _queueElementWrapper = queueElementWrapper
  }

  mutating func next() -> Wrapper.Element? {
    if let wrapper = _queueElementWrapper {
      _queueElementWrapper = wrapper.next
      return wrapper.element
    } else {
      return nil
    }
  }
}
