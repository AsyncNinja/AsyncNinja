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

/// Is a simple cache that can contain single value. Does not invalidate
/// cached values automatically. Parametrised with MutableCompletable
/// that can be either `Future` or `Channel` and Context. That gives
/// an opportunity to make cache that can report of status of completion
/// updateally (e.g. download persentage).
public class CachableValue<T: MutableCompletable, Context: ExecutionContext> {

  /// Function that resolves cache misses. `strongContext` is a context restored from weak reference
  public typealias MissHandler = (_ strongContext: Context) throws -> T.ImmutableCompletable
  private var _locking = makeLocking()
  private let _impl: CachableValueImpl<T, Context>

  /// Designated initializer
  ///
  /// - Parameters:
  ///   - context: context that owns CahableValue
  ///   - missHandler: block that handles cache misses
  ///   - strongContext: context restored from weak reference
  public init(context: Context, missHandler: @escaping MissHandler) {
    _impl = CachableValueImpl(context: context, missHandler: missHandler)
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
    mustInvalidateOldValue: Bool = false
    ) -> T.ImmutableCompletable {
    _locking.lock()
    defer { _locking.unlock() }
    return _impl.value(mustStartHandlingMiss: mustStartHandlingMiss,
                       mustInvalidateOldValue: mustInvalidateOldValue)
  }

  /// Invalidates cached value
  public func invalidate() {
    _locking.lock()
    defer { _locking.unlock() }
    return _impl.invalidate()
  }
}

/// **Internal use only** Implementation of CachableValue.
class CachableValueImpl<T: MutableCompletable, Context: ExecutionContext> {
  typealias MissHandler = CachableValue<T, Context>.MissHandler
  private weak var _context: Context?
  private let _missHandler: MissHandler
  private var _mutableCompletable = T()
  private var _state: CachableValueState = .initial

  init(context: Context, missHandler: @escaping MissHandler) {
    _context = context
    _missHandler = missHandler
  }

  func value(mustStartHandlingMiss: Bool,
             mustInvalidateOldValue: Bool
    ) -> T.ImmutableCompletable {
    switch _state {
    case .initial:
      if mustStartHandlingMiss {
        _handleMiss()
      }
    case .handling:
      nop()
    case .finished:
      if mustInvalidateOldValue {
        _mutableCompletable = T()
        _state = .initial
        if mustStartHandlingMiss {
          _handleMiss()
        }
      }
    }
    return _mutableCompletable as! T.ImmutableCompletable
  }

  private func _handleMiss() {
    _state = .handling
    let mutableCompletable = _mutableCompletable

    guard let context = _context else {
      mutableCompletable.fail(with: AsyncNinjaError.contextDeallocated)
      return
    }

    context.executor.execute { [weak self] in
      guard let self_ = self else { return }
      //let mutableCompletable = self_._mutableCompletable
      guard let context = self_._context else {
        mutableCompletable.fail(with: AsyncNinjaError.contextDeallocated)
        return
      }

      assert(mutableCompletable === self_._mutableCompletable)

      do {
        let completable = try self_._missHandler(context)
        completable.onComplete(context: context) {
          [weak self_] (context, fallible) in
          guard let self__ = self_ else { return }
          self__._state = .finished
          do {
            let success = try fallible.liftSuccess()
            mutableCompletable.succeed(with: success as! T.Success)
          } catch {
            mutableCompletable.fail(with: error)
          }
        }
        mutableCompletable.complete(with: completable)
      } catch {
        self_._state = .finished
        mutableCompletable.fail(with: error)
      }
    }
  }

  public func invalidate() {
    let _ = value(mustStartHandlingMiss: false, mustInvalidateOldValue: true)
  }
}

private enum CachableValueState {
  case initial
  case handling
  case finished
}

/// Convenience typealias for CachableValue based on `Future`
public typealias SimpleCachableValue<Success, Context: ExecutionContext>
  = CachableValue<Promise<Success>, Context>

/// Convenience typealias for CachableValue based on `Channel`
public typealias ReportingCachableValue<Update, Success, Context: ExecutionContext>
  = CachableValue<Producer<Update, Success>, Context>
