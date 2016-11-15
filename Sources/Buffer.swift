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
  private var _container = QueueImpl<Value>()
  private var _locking = makeLocking()

  init(size: Int) {
    assert(size > 0)
    self.maxSize = size
  }

  init<S: Sequence>(_ sequence: S, maxSize: Int? = nil) where S.Iterator.Element == Value {
    let container = Array(sequence)
    self.maxSize = maxSize ?? container.count
    for value in sequence {
      _container.push(value)
    }
  }
  
  private mutating func _push(_ value: Value) {
    _container.push(value)
    if self.size > self.maxSize {
      let _ = _container.pop()
    }
  }

  mutating func push(_ value: Value) {
    _locking.lock()
    defer { _locking.unlock() }
    self._push(value)
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

    var iterator = _container.makeIterator()
    while let value = iterator.next() {
      block(value)
    }
  }

  mutating func pop() -> Value? {
    _locking.lock()
    defer { _locking.unlock() }
    return _container.pop()
  }

  mutating func reset() {
    _locking.lock()
    defer { _locking.unlock() }
    _container.removeAll()
  }
}
