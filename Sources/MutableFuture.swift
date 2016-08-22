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

public class MutableFuture<T> : Future<T> {
  private let _sema = DispatchSemaphore(value: 1)
  private var _handlers = ContiguousArray<Handler>()
  private var value: Value?
  private var _aliveKeeper: MutableFuture<T>?

  override func add(handler: FutureHandler<T>) {
    _sema.wait()
    defer { _sema.signal() }
    if let value = self.value {
      handler.handle(value: value)
    } else {
      _aliveKeeper = self
      _handlers.append(handler)
    }
  }

  @discardableResult
  final func tryUpdateAndMakeValue(with block: (Void) -> Value?) {
    _sema.wait()
    defer { _sema.signal() }

    guard nil == self.value else { return }
    guard let value = block() else { return }
    self.value = value
    func apply(handler: Handler) {
      handler.executor.execute { handler.block(value) }
    }
    _handlers.forEach(apply)
    _handlers = []
    _aliveKeeper = nil
  }
}

typealias MutableFallibleFuture<T> = MutableFuture<Fallible<T>>
