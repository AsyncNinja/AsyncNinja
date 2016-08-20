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

class QueueImpl<T> {
  typealias Wrapper = QueueElementWrapper<T>

  var _first: Wrapper? = nil
  var _last: Wrapper? = nil

  init() { }

  func push(_ element: T) {
    let new = Wrapper(element: element)
    if let last = _last {
      last.next = new
    } else {
      _first = new
    }
    _last = new
  }

  func pop() -> T? {
    guard let first = _first else { return nil }
    if let next = first.next {
      _first = next
    } else {
      _last = nil
    }

    return first.element
  }

  var isEmpty: Bool { return nil == _first }
}

class QueueElementWrapper<T> {
  let element: T
  var next: QueueElementWrapper<T>?

  init(element: T) {
    self.element = element
  }
}
