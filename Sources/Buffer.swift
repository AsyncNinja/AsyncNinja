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

func makeBuffer<Value>(size: Int) -> Buffer<Value> {
  switch size {
  case 0: return BufferOfNone()
  case 1: return BufferOfOne()
  default: return BufferOfMany(size: size)
  }
}

class Buffer<Value> {
  var size: Int {
    /* abstract */
    fatalError()
  }

  fileprivate init() { }

  func push(_ value: Value) {
    /* abstract */
    fatalError()
  }
  
  func push<S : Sequence>(_ values: S)
    where S.Iterator.Element == Value {
      /* abstract */
      fatalError()
  }

  func apply(_ block: (Value) -> Void) {
    /* abstract */
    fatalError()
  }

  func reset() {
    /* abstract */
    fatalError()
  }
}

final private class BufferOfNone<Value> : Buffer<Value> {
  override var size: Int { return 0 }

  override fileprivate init() { }

  override func push(_ value: Value) { /* do nothing */ }
  
  override func push<S : Sequence>(_ values: S)
    where S.Iterator.Element == Value  { /* do nothing */ }

  override func apply(_ block: (Value) -> Void) { /* do nothing */ }

  override func reset() { /* do nothing */ }
}

final private class BufferOfOne<Value> : Buffer<Value> {
  var _value: Value?
  override var size: Int { return 1 }

  override fileprivate init() { }

  override func push(_ value: Value) {
    _value = value
  }
  
  override func push<S : Sequence>(_ values: S)
    where S.Iterator.Element == Value  {
      if let value = values.suffix(1).makeIterator().next() {
        _value = value
      }
  }

  override func apply(_ block: (Value) -> Void) {
    if let value = _value {
      block(value)
    }
  }

  override func reset() {
    _value = nil
  }
}

final private class BufferOfMany<Value> : Buffer<Value> {
  private let _size: Int
  private var _container = [Value]()
  private var _indexUpperBound = 0
  private let _locking = makeLocking()
  override var size: Int { return _size }

  fileprivate init(size: Int) {
    assert(size > 0)
    _size = size
  }
  
  private func _push(_ value: Value) {
    if _container.count < _size {
      _container.append(value)
    } else {
      _container[_indexUpperBound % _size] = value
      _indexUpperBound += 1
    }
  }

  override func push(_ value: Value) {
    _locking.lock()
    defer { _locking.unlock() }
    if _container.count < _size {
      _container.append(value)
    } else {
      _container[_indexUpperBound % _size] = value
      _indexUpperBound += 1
    }
  }
  
  override func push<S : Sequence>(_ values: S)
    where S.Iterator.Element == Value  {
      _locking.lock()
      defer { _locking.unlock() }
      values.suffix(_size).forEach(self._push)
  }

  override func apply(_ block: (Value) -> Void) {
    _locking.lock()
    defer { _locking.unlock() }

    for index in 0..<_container.count {
      let value = _container[(index + _indexUpperBound) % _size]
      block(value)
    }
  }

  override func reset() {
    _locking.lock()
    defer { _locking.unlock() }
    _container.removeAll()
    _indexUpperBound = 0
  }
}
