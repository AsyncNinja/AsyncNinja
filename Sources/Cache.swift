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

import Dispatch

/// Is a simple cache that can contain multiple values by unique
/// hashable key. Does not invalidate cached values automatically.
/// Parametrised with Key, T that can be either
/// `Future` or `Channel` and Context. That gives an opportunity to make
/// cache that can report of status of completion updateally
/// (e.g. download persentage).
public class Cache<Key: Hashable, T: Completable, Context: ExecutionContext> {
  typealias _CachableValue = CachableValueImpl<T, Context>

  /// Block that resolves miss
  public typealias MissHandler = (_ strongContext: Context, _ key: Key) throws -> T.CompletingType

  private var _locking = makeLocking()
  private weak var _context: Context?
  private let _missHandler: (Context, Key) throws -> T.CompletingType
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
  public func value(forKey key: Key, mustStartHandlingMiss: Bool = true, mustInvalidateOldValue: Bool = false) -> T.CompletingType {
    guard let context = _context else {
      let completing = T()
      completing.fail(with: AsyncNinjaError.contextDeallocated)
      return completing as! T.CompletingType
    }

    _locking.lock()
    defer { _locking.unlock() }
    func makeCachableValue(key: Key) -> _CachableValue {
      let missHandler = _missHandler
      return _CachableValue(context: context) {
        try missHandler($0, key)
      }
    }
    return _cachedValuesByKey
      .value(forKey: key, orMake: makeCachableValue)
      .value(mustStartHandlingMiss: mustStartHandlingMiss, mustInvalidateOldValue: mustInvalidateOldValue)
  }

  /// Invalidates cached value for specified key
  public func invalidate(valueForKey key: Key) {
    let _ = value(forKey: key, mustStartHandlingMiss: false, mustInvalidateOldValue: true)
  }
}

/// Convenience typealias for Cache based on `Future`
public typealias SimpleCache<Key: Hashable, Value, Context: ExecutionContext> = Cache<Key, Promise<Value>, Context>

/// Convenience typealias for Cache based on `Channel`
public typealias ReportingCache<Key: Hashable, Update, Success, Context: ExecutionContext> = Cache<Key, Producer<Update, Success>, Context>

/// Convenience function that makes `SimpleCache`
public func makeCache<Key: Hashable, Value, Context: ExecutionContext>(
  context: Context,
  missHandler: @escaping (Context, Key) -> Future<Value>
  ) -> SimpleCache<Key, Value, Context> {
  return Cache(context: context, missHandler: missHandler)
}

/// Convenience function that makes `ReportingCache`
public func makeCache<Key: Hashable, Update, Success, Context: ExecutionContext>(
  context: Context,
  missHandler: @escaping (Context, Key) -> Channel<Update, Success>
  ) -> ReportingCache<Key, Update, Success, Context> {
  return Cache(context: context, missHandler: missHandler)
}
