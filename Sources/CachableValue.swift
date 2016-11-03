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

public class CachableValue<Value, Context: ExecutionContext> : ExecutionContextProxy {
  public var context: ExecutionContext { return _context }
  private let _missHandler: (Context) -> Future<Value>
  private var _mutableFinite = Promise<Value>()
  private var _state: CachableValueState = .initial
  public let _context: Context
  
  public init(context context_: Context, missHandler: @escaping (Context) -> Future<Value>) {
    _context = context_
    _missHandler = missHandler
  }
  
  public func value(mustStartHandlingMiss: Bool = true, mustInvalidateOldValue: Bool = false) -> Future<Value> {
    return future(context: self) { (self) -> Future<Value> in
      switch self._state {
      case .initial:
        if mustStartHandlingMiss {
          self._handleMiss()
        }
      case .handling:
        nop()
      case .finished:
        if mustInvalidateOldValue {
          self._mutableFinite = Promise()
          self._state = .initial
          if mustStartHandlingMiss {
            self._handleMiss()
          }
        }
      }
      return self._mutableFinite
      }
      .flatten()
  }
  
  private func _handleMiss() {
    self._state = .handling
    _mutableFinite.complete(with: _missHandler(_context))
  }
  
  public func invalidate() {
    let _ = self.value(mustStartHandlingMiss: false, mustInvalidateOldValue: true)
  }
}

private enum CachableValueState {
  case initial
  case handling
  case finished
}

func nop() {
  // no operation
}
