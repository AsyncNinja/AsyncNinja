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
/// cached values automatically. Parametrised with Completable
/// that can be either `Future` or `Channel` and Context. That gives
/// an opportunity to make cache that can report of status of completion
/// updateally (e.g. download persentage).
public class CachableValue<T: Completable, Context: ExecutionContext> {

  /// Function that resolves cache misses. `strongContext` is a context restored from weak reference
  public typealias MissHandler = (_ strongContext: Context) throws -> T.CompletingType
  private var _lockingBox: MutableBox<Locking>
  private let _impl: CachableValueImpl<T, Context>

  /// Designated initializer
  ///
  /// - Parameters:
  ///   - context: context that owns CahableValue
  ///   - missHandler: block that handles cache misses
  ///   - strongContext: context restored from weak reference
  public init(context: Context, missHandler: @escaping MissHandler) {
    let lockingBox = MutableBox(makeLocking())
    _lockingBox = lockingBox
    _impl = CachableValueImpl(context: context,
                              locker: { lockingBox.value.locker($0) },
                              missHandler: missHandler)
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
    ) -> T.CompletingType {
    _lockingBox.value.lock()
    defer { _lockingBox.value.unlock() }
    return _impl.value(mustStartHandlingMiss: mustStartHandlingMiss,
                       mustInvalidateOldValue: mustInvalidateOldValue)
  }

  /// Invalidates cached value
  public func invalidate() {
    _lockingBox.value.lock()
    defer { _lockingBox.value.unlock() }
    return _impl.invalidate()
  }
}

/// **Internal use only** Implementation of CachableValue.
class CachableValueImpl<T: Completable, Context: ExecutionContext> {
  typealias MissHandler = CachableValue<T, Context>.MissHandler
  private weak var _context: Context?
  private let _locker: (() -> Void) -> Void
  private let _missHandler: MissHandler
  private var _completing = T()
  private var _state: CachableValueState = .initial

  init(context: Context, locker: @escaping (() -> Void) -> Void, missHandler: @escaping MissHandler) {
    _context = context
    _locker = locker
    _missHandler = missHandler
  }

  func value(mustStartHandlingMiss: Bool,
             mustInvalidateOldValue: Bool
    ) -> T.CompletingType {
    switch _state {
    case .initial:
      if mustStartHandlingMiss {
        _handleMiss()
      }
    case .handling:
      nop()
    case .finished:
      if mustInvalidateOldValue {
        _completing = T()
        _state = .initial
        if mustStartHandlingMiss {
          _handleMiss()
        }
      }
    }
    return _completing as! T.CompletingType
  }

  private func _handleMiss() {
    _state = .handling

    guard let context = _context else {
      _completing.fail(with: AsyncNinjaError.contextDeallocated)
      return
    }

    context.executor.execute { [weak self] in
      self?._handleMissOnExecutor()
    }
  }

  private func _handleMissOnExecutor() {
    guard let context = self._context else {
      _completing.fail(with: AsyncNinjaError.contextDeallocated)
      return
    }

    do {
      let completable = try _missHandler(context)
      completable.onComplete(executor: .immediate) {
        [weak self] (completion) in
        self?._handle(completion: completion)
      }
    } catch {
      _state = .finished
      _completing.fail(with: error)
    }
  }

  private func _handle(completion: Fallible<T.CompletingType.Success>) {
    _locker {
      _state = .finished
      switch completion {
      case .success(let success):
        _completing.succeed(with: success as! T.Success)
      case .failure(let failure):
        _completing.fail(with: failure)
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
