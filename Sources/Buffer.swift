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

struct Buffer<Value> {
  let maxSize: Int
  var size: Int { return Int(self._container.count) }
  private var _container: [Value]
  private var _indexUpperBound = 0
  private var _locking = makeLocking()

  init(size: Int) {
    assert(size > 0)
    self.maxSize = size
    _container = []
  }

  init<S: Sequence>(_ sequence: S, maxSize: Int? = nil) where S.Iterator.Element == Value {
    let container = Array(sequence)
    self.maxSize = maxSize ?? container.count
    _container = container
  }
  
  private mutating func _push(_ value: Value) {
    if self.size < self.maxSize {
      _container.append(value)
    } else {
      _container[_indexUpperBound % self.maxSize] = value
      _indexUpperBound += 1
    }
  }

  mutating func push(_ value: Value) {
    _locking.lock()
    defer { _locking.unlock() }
    if _container.count < self.maxSize {
      _container.append(value)
    } else {
      _container[_indexUpperBound % self.maxSize] = value
      _indexUpperBound += 1
    }
  }
  
  mutating func push<S : Sequence>(_ values: S)
    where S.Iterator.Element == Value  {
      _locking.lock()
      defer { _locking.unlock() }
      for value in values.suffix(self.maxSize) {
        self.push(value)
      }
  }

  mutating func apply(_ block: (Value) -> Void) {
    _locking.lock()
    defer { _locking.unlock() }

    for index in 0..<_container.count {
      let value = _container[(index + _indexUpperBound) % self.maxSize]
      block(value)
    }
  }

  mutating func reset() {
    _locking.lock()
    defer { _locking.unlock() }
    _container.removeAll()
    _indexUpperBound = 0
  }
}
