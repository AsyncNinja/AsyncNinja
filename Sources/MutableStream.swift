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

public class MutableStream<T> : Stream<T> {
  private var _sema = DispatchSemaphore(value: 1)
  private var _handlers = [Handler]()

  override public init() { }

  override public func onValue(executor: Executor, block: (Value) -> Void) {
    _sema.wait()
    defer { _sema.signal() }
    _handlers.append((executor: executor, block: block))
  }

  public func send(_ value: Value) {
    _sema.wait()
    defer { _sema.signal() }
    for (executor, block) in _handlers {
      executor.execute { block(value) }
    }
  }

  public func send<S: Sequence where S.Iterator.Element == Value>(_ values: S) {
    _sema.wait()
    defer { _sema.signal() }
    for value in values {
      for (executor, block) in _handlers {
        executor.execute { block(value) }
      }
    }
  }
}
