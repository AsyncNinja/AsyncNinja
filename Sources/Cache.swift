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

public class Cache<Key : Hashable, MutableFiniteValue : MutableFinite, Context : ExecutionContext> {
  typealias _CachableValue = CachableValueImpl<MutableFiniteValue, Context>
  
  private var _locking = makeLocking()
  public let _context: Context
  private let _missHandler: (Context) -> MutableFiniteValue.ImmutableFinite
  private var _cachedValuesByKey = [Key:_CachableValue]()
  
  public init(context: Context, missHandler: @escaping (Context) -> MutableFiniteValue.ImmutableFinite) {
    _context = context
    _missHandler = missHandler
  }

  public func value(key: Key, mustStartHandlingMiss: Bool = true, mustInvalidateOldValue: Bool = false) -> MutableFiniteValue.ImmutableFinite {
    _locking.lock()
    defer { _locking.unlock() }
    func makeCachableValue(key: Key) -> _CachableValue {
      return _CachableValue(context: self._context, missHandler: self._missHandler)
    }
    return self._cachedValuesByKey
      .value(forKey: key, orMake: makeCachableValue)
      .value(mustStartHandlingMiss: mustStartHandlingMiss, mustInvalidateOldValue: mustInvalidateOldValue)
  }
  
  public func invalidate(valueForKey key: Key) {
    let _ = self.value(key: key, mustStartHandlingMiss: false, mustInvalidateOldValue: true)
  }
}

public typealias SimpleCache<Key : Hashable, Value, Context : ExecutionContext> = Cache<Key, Promise<Value>, Context>
public typealias ReportingCache<Key : Hashable, PeriodicValue, FinalValue, Context : ExecutionContext> = Cache<Key, Producer<PeriodicValue, FinalValue>, Context>

public func makeCache<Key: Hashable, Value, Context: ExecutionContext>(
  context: Context,
  missHandler: @escaping (Context) -> Future<Value>
  ) -> SimpleCache<Key, Value, Context> {
  return Cache(context: context, missHandler: missHandler)
}

public func makeCache<Key: Hashable, PeriodicValue, FinalValue, Context: ExecutionContext>(
  context: Context,
  missHandler: @escaping (Context) -> Channel<PeriodicValue, FinalValue>
  ) -> ReportingCache<Key, PeriodicValue, FinalValue, Context> {
  return Cache(context: context, missHandler: missHandler)
}
