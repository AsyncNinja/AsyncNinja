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

/// Protocol for a Completable that can be used for cachable
public protocol CachableCompletable: Completable {
  associatedtype CompletingType: Completing

  /// Required initializer
  init()
}

/// Is a simple cache that can contain single value. Does not invalidate
/// cached values automatically. Parametrised with Completable
/// that can be either `Future` or `Channel` and Context. That gives
/// an opportunity to make cache that can report of status of completion
/// updateally (e.g. download persentage).
public class CachableValue<T: CachableCompletable> {
  public typealias MissHandler = () throws -> T.CompletingType
  private let _executor: Executor
  private var _locking = makeLocking()
  private let _missHandler: MissHandler
  private var _completing = T()
  private var _state: CachableValueState = .initial

  /// Designated initializer
  ///
  /// - Parameters:
  ///   - executor: executor to call miss handle on
  ///   - missHandler: block that handles cache misses
  public init(executor: Executor = .primary, missHandler: @escaping MissHandler) {
    _executor = executor
    _missHandler = missHandler
  }

  /// Convenience initializer
  ///
  /// - Parameters:
  ///   - context: context that owns CachableValue
  ///   - executor: override of `ExecutionContext`s executor.
  ///     Keep default value of the argument unless you need to override
  ///     an executor provided by the context
  ///   - missHandler: block that handles cache misses
  ///   - strongContext: context restored from weak reference
  public convenience init<C: ExecutionContext>(
    context: C,
    executor: Executor? = nil,
    missHandler: @escaping (_ strongContext: C) throws -> T.CompletingType) {
    self.init(executor: executor ?? context.executor) { [weak context] in
      if let context = context {
        return try missHandler(context)
      } else {
        throw AsyncNinjaError.contextDeallocated
      }
    }
  }

  /// Fetches value
  ///
  /// - Parameters:
  ///   - mustStartHandlingMiss: `true` if handling miss is allowed.
  ///     `false` is useful if you want to use value if there is one
  ///     and do not want to handle miss.
  ///   - mustInvalidateOldValue: `true` if previous value may not be used.
  /// - Returns: `Future` of `Channel`
  public func value(
    mustStartHandlingMiss: Bool = true,
    mustInvalidateOldValue: Bool = false,
    from originalExecutor: Executor? = nil
    ) -> T.CompletingType {

    let (shouldHandle, result): (Bool, T.CompletingType) = _locking.locker {
      switch _state {
      case .initial:
        if mustStartHandlingMiss {
          _state = .handling
          return (true, _completing as! T.CompletingType)
        } else {
          return (false, _completing as! T.CompletingType)
        }
      case .handling:
        return (false, _completing as! T.CompletingType)
      case .finished:
        if mustInvalidateOldValue {
          _completing = T()
          if mustStartHandlingMiss {
            _state = .handling
            return (true, _completing as! T.CompletingType)
          } else {
            _state = .initial
            return (false, _completing as! T.CompletingType)
          }
        } else {
          return (false, _completing as! T.CompletingType)
        }
      }
    }

    if shouldHandle {
      _executor.execute(from: originalExecutor) { [weak self] (originalExecutor) in
        self?._handleMissOnExecutor(from: originalExecutor)
      }
    }

    return result
  }

  /// Invalidates cached value
  public func invalidate() {
    _ = value(mustStartHandlingMiss: false, mustInvalidateOldValue: true)
  }

  private func _handleMissOnExecutor(from originalExecutor: Executor?) {
    do {
      let completable = try _missHandler()
      _ = completable._onComplete(
        executor: .immediate
      ) { [weak self] (completion, originalExecutor) in
        self?._handle(completion: completion, from: originalExecutor)
      }
    } catch {
      _locking.lock()
      _state = .finished
      _locking.unlock()
      _completing.fail(error, from: originalExecutor)
    }
  }

  private func _handle(completion: Fallible<T.CompletingType.Success>, from originalExecutor: Executor) {
    _locking.lock()
    let completing = _completing
    _state = .finished
    _locking.unlock()

    switch completion {
    case .success(let success):
      completing.succeed(success as! T.Success, from: originalExecutor)
    case .failure(let failure):
      completing.fail(failure, from: originalExecutor)
    }
  }
}

private enum CachableValueState {
  case initial
  case handling
  case finished
}

/// Convenience typealias for CachableValue based on `Future`
public typealias SimpleCachableValue<Success>
  = CachableValue<Promise<Success>>

/// Convenience typealias for CachableValue based on `Channel`
public typealias ReportingCachableValue<Update, Success>
  = CachableValue<Producer<Update, Success>>
