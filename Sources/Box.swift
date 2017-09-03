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

/// **Internal use only**
class Box<T> {
  let value: T

  init(_ value: T) {
    self.value = value
  }
}

/// **Internal use only**
class MutableBox<T> {
  var value: T

  init(_ value: T) {
    self.value = value
  }
}

/// **Internal use only**
class AtomicMutableBox<T> {
  var value: T {
    get {
      return _locking.locker { self._value }
    }
    set {
      // this tricky code is made to avoid deinitialization with lock
      // because deinitialization can ask for lock too

      _locking.lock()
      var oldValue: T? = _value // reference count of old value +1
      _value = newValue // reference count of old value -1
      _locking.unlock()
      _ = oldValue
      oldValue = nil // reference count of old value -1
    }
  }
  private var _value: T
  private var _locking = makeLocking()

  init(_ value: T) {
    _value = value
  }
}

/// **Internal use only**
class WeakBox<T: AnyObject> {
  private(set) weak var value: T?

  init(_ value: T) {
    self.value = value
  }
}

/// **Internal use only**
class HalfRetainer<T> {
  let box: AtomicMutableBox<T?>

  init(box: AtomicMutableBox<T?>) {
    self.box = box
  }

  deinit {
    box.value = nil
  }
}
