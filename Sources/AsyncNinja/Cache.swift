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
public class Cache<Key: Hashable, T: CachableCompletable> {
  typealias LocalCachableValue = CachableValue<T>

  /// Block that resolves miss
  public typealias MissHandler = (_ key: Key) throws -> T.CompletingType

  private var _locking = makeLocking()
  private let _executor: Executor
  private let _missHandler: (Key) throws -> T.CompletingType
  private var _cachedValuesByKey = [Key: LocalCachableValue]()

  /// Designated initializer
  ///
  /// - Parameters:
  ///   - executor: executor to call miss handler o
  ///   - missHandler: block that handles cache misses
  public init(executor: Executor = .primary, _ missHandler: @escaping MissHandler) {
    _executor = executor
    _missHandler = missHandler
  }

  /// Convenience initializer
  ///
  /// - Parameters:
  ///   - context: context that owns Cache
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - missHandler: block that handles cache misses
  ///   - strongContext: context restored from weak reference
  public convenience init<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    _ missHandler: @escaping (_ strongContext: C, _ key: Key) throws -> T.CompletingType) {
    self.init(executor: executor ?? context.executor) { [weak context] (key) in
      if let context = context {
        return try missHandler(context, key)
      } else {
        throw AsyncNinjaError.contextDeallocated
      }
    }
  }

  /// Fetches value
  ///
  /// - Parameters:
  ///   - key: to fetch value for
  ///   - mustStartHandlingMiss: `true` if handling miss is allowed.
  ///     `false` is useful if you want to use value if there is one and do not want to handle miss.
  ///   - mustInvalidateOldValue: `true` if previous value may not be used.
  /// - Returns: `Future` of `Channel`
  public func value(
    forKey key: Key,
    mustStartHandlingMiss: Bool = true,
    mustInvalidateOldValue: Bool = false,
    from originalExecutor: Executor? = nil) -> T.CompletingType {
    let cachableValueForKey: LocalCachableValue = _locking.locker {
      func makeCachableValue(key: Key) -> LocalCachableValue {
        let missHandler = _missHandler
        return CachableValue(executor: _executor) {
          try missHandler(key)
        }
      }
      return self._cachedValuesByKey
        .value(forKey: key, orMake: makeCachableValue(key:))
    }

    return cachableValueForKey.value(mustStartHandlingMiss: mustStartHandlingMiss,
                                     mustInvalidateOldValue: mustInvalidateOldValue,
                                     from: originalExecutor)
  }

  /// Invalidates cached value for specified key
  public func invalidate(valueForKey key: Key) {
    _ = value(forKey: key, mustStartHandlingMiss: false, mustInvalidateOldValue: true)
  }
}

/// Convenience typealias for Cache based on `Future`
public typealias SimpleCache<Key: Hashable, Value> = Cache<Key, Promise<Value>>

/// Convenience typealias for Cache based on `Channel`
public typealias ReportingCache<Key: Hashable, Update, Success> = Cache<Key, Producer<Update, Success>>

/// Convenience function that makes `SimpleCache`
public func makeCache<Key, Value>(
  executor: Executor = .primary,
  missHandler: @escaping (Key) throws -> Future<Value>
  ) -> SimpleCache<Key, Value> {
  return Cache(executor: executor, missHandler)
}

/// Convenience function that makes `SimpleCache`
public func makeCache<Key, Value, Context: ExecutionContext>(
  context: Context,
  executor: Executor? = nil,
  _ missHandler: @escaping (Context, Key) throws -> Future<Value>
  ) -> SimpleCache<Key, Value> {
  return Cache(context: context, executor: executor, missHandler)
}

/// Convenience function that makes `ReportingCache`
public func makeCache<Key, Update, Success>(
  executor: Executor = .primary,
  _ missHandler: @escaping (Key) throws -> Channel<Update, Success>
  ) -> ReportingCache<Key, Update, Success> {
  return Cache(executor: executor, missHandler)
}

/// Convenience function that makes `ReportingCache`
public func makeCache<Key, Update, Success, Context: ExecutionContext>(
  context: Context,
  executor: Executor? = nil,
  _ missHandler: @escaping (Context, Key) throws -> Channel<Update, Success>
  ) -> ReportingCache<Key, Update, Success> {
  return Cache(context: context, executor: executor, missHandler)
}
