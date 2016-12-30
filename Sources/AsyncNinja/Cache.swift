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

/// Is a simple cache that can contain multiple values by unique hashable key. Does not invalidate cached values automatically. Parametrised with Key, MutableFiniteValue that can be either `Future` or `Channel` and Context. That gives an opportunity to make cache that can report of status of completion periodically (e.g. download persentage).
public class Cache<Key : Hashable, MutableFiniteValue : MutableFinite, Context : ExecutionContext> {
  typealias _CachableValue = CachableValueImpl<MutableFiniteValue, Context>

  /// Block that resolves miss
  public typealias MissHandler = (_ strongContext: Context, _ key: Key) throws -> MutableFiniteValue.ImmutableFinite
  
  private var _locking = makeLocking()
  private weak var _context: Context?
  private let _missHandler: (Context, Key) throws -> MutableFiniteValue.ImmutableFinite
  private var _cachedValuesByKey = [Key:_CachableValue]()
  
  /// Designated initializer
  ///
  /// - Parameters:
  ///   - context: context that owns CahableValue
  ///   - missHandler: block that handles cache misses
  public init(context: Context, missHandler: @escaping MissHandler) {
    _context = context
    _missHandler = missHandler
  }

  /// Fetches value
  ///
  /// - Parameters:
  ///   - key: to fetch value for
  ///   - mustStartHandlingMiss: `true` if handling miss is allowed. `false` is useful if you want to use value if there is one and do not want to handle miss.
  ///   - mustInvalidateOldValue: `true` if previous value may not be used.
  /// - Returns: `Future` of `Channel`
  public func value(forKey key: Key, mustStartHandlingMiss: Bool = true, mustInvalidateOldValue: Bool = false) -> MutableFiniteValue.ImmutableFinite {
    guard let context = _context else {
      let mutableFinite = MutableFiniteValue()
      mutableFinite.fail(with: AsyncNinjaError.contextDeallocated)
      return mutableFinite as! MutableFiniteValue.ImmutableFinite
    }
    
    _locking.lock()
    defer { _locking.unlock() }
    func makeCachableValue(key: Key) -> _CachableValue {
      let missHandler = self._missHandler
      return _CachableValue(context: context) {
        try missHandler($0, key)
      }
    }
    return self._cachedValuesByKey
      .value(forKey: key, orMake: makeCachableValue)
      .value(mustStartHandlingMiss: mustStartHandlingMiss, mustInvalidateOldValue: mustInvalidateOldValue)
  }
  
  /// Invalidates cached value for specified key
  public func invalidate(valueForKey key: Key) {
    let _ = self.value(forKey: key, mustStartHandlingMiss: false, mustInvalidateOldValue: true)
  }
}

/// Convenience typealias for Cache based on `Future`
public typealias SimpleCache<Key : Hashable, Value, Context : ExecutionContext> = Cache<Key, Promise<Value>, Context>

/// Convenience typealias for Cache based on `Channel`
public typealias ReportingCache<Key : Hashable, PeriodicValue, FinalValue, Context : ExecutionContext> = Cache<Key, Producer<PeriodicValue, FinalValue>, Context>

/// Convenience function that makes `SimpleCache`
public func makeCache<Key: Hashable, Value, Context: ExecutionContext>(
  context: Context,
  missHandler: @escaping (Context, Key) -> Future<Value>
  ) -> SimpleCache<Key, Value, Context> {
  return Cache(context: context, missHandler: missHandler)
}

/// Convenience function that makes `ReportingCache`
public func makeCache<Key: Hashable, PeriodicValue, FinalValue, Context: ExecutionContext>(
  context: Context,
  missHandler: @escaping (Context, Key) -> Channel<PeriodicValue, FinalValue>
  ) -> ReportingCache<Key, PeriodicValue, FinalValue, Context> {
  return Cache(context: context, missHandler: missHandler)
}
