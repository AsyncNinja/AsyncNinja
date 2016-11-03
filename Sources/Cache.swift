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

public class Cache<Key: Hashable, Value, Context: ExecutionContext> : ExecutionContextProxy {
  typealias _CachableValue = CachableValue<Value, Context>
  
  public var context: ExecutionContext { return _context }
  private let _missHandler: (Context) -> Future<Value>
  public let _context: Context
  private var _cachedValuesByKey = [Key:_CachableValue]()
  
  public init(context context_: Context, missHandler: @escaping (Context) -> Future<Value>) {
    _context = context_
    _missHandler = missHandler
  }

  public func value(key: Key, mustStartHandlingMiss: Bool = true, mustInvalidateOldValue: Bool = false) -> Future<Value> {
    return future(context: self) { (self) -> Future<Value> in
      
      func makeCachableValue(key: Key) -> _CachableValue {
        return CachableValue(context: self._context, missHandler: self._missHandler)
      }
      return self._cachedValuesByKey
        .value(forKey: key, orMake: makeCachableValue)
        ._value(mustStartHandlingMiss: mustStartHandlingMiss, mustInvalidateOldValue: mustInvalidateOldValue)
      }
      .flatten()
  }
  
  public func invalidate(valueForKey key: Key) {
    let _ = self.value(key: key, mustStartHandlingMiss: false, mustInvalidateOldValue: true)
  }
}
