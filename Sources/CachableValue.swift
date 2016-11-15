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

public class CachableValue<MutableFiniteValue : MutableFinite, Context: ExecutionContext> {
  private var _locking = makeLocking()
  private let _impl: CachableValueImpl<MutableFiniteValue, Context>
  
  public init(context: Context, missHandler: @escaping (Context) throws -> MutableFiniteValue.ImmutableFinite) {
    _impl = CachableValueImpl(context: context, missHandler: missHandler)
  }
  
  public func value(mustStartHandlingMiss: Bool = true, mustInvalidateOldValue: Bool = false) -> MutableFiniteValue.ImmutableFinite {
    _locking.lock()
    defer { _locking.unlock() }
    return _impl.value(mustStartHandlingMiss: mustStartHandlingMiss, mustInvalidateOldValue: mustInvalidateOldValue)
  }
  
  public func invalidate() {
    _locking.lock()
    defer { _locking.unlock() }
    return _impl.invalidate()
  }
}

class CachableValueImpl<MutableFiniteValue : MutableFinite, Context: ExecutionContext> {
  private weak var _context: Context?
  private let _missHandler: (Context) throws -> MutableFiniteValue.ImmutableFinite
  private var _mutableFinite = MutableFiniteValue()
  private var _state: CachableValueState = .initial
  
  init(context: Context, missHandler: @escaping (Context) throws -> MutableFiniteValue.ImmutableFinite) {
    _context = context
    _missHandler = missHandler
  }
  
  func value(mustStartHandlingMiss: Bool, mustInvalidateOldValue: Bool) -> MutableFiniteValue.ImmutableFinite {
    switch self._state {
    case .initial:
      if mustStartHandlingMiss {
        self._handleMiss()
      }
    case .handling:
      nop()
    case .finished:
      if mustInvalidateOldValue {
        self._mutableFinite = MutableFiniteValue()
        self._state = .initial
        if mustStartHandlingMiss {
          self._handleMiss()
        }
      }
    }
    return self._mutableFinite as! MutableFiniteValue.ImmutableFinite
  }
  
  private func _handleMiss() {
    _state = .handling
    let mutableFinite = _mutableFinite
    if let context = _context {
      context.executor.execute { [weak self] in
        guard let self_ = self else { return }
        let mutableFinite = self_._mutableFinite
        guard let context = self_._context else {
          mutableFinite.fail(with: AsyncNinjaError.contextDeallocated)
          return
        }

        assert(mutableFinite === self?._mutableFinite)

        do {
          let finite = try self_._missHandler(context)
          finite.onComplete(context: context) { [weak self_] (context, fallible) in
            guard let self__ = self_ else { return }
            self__._state = .finished
            do {
              let success = try fallible.liftSuccess()
              self__._mutableFinite.succeed(with: success as! MutableFiniteValue.FinalValue)
            } catch {
              self__._mutableFinite.fail(with: error)
            }
          }
          mutableFinite.complete(with: finite)
        } catch {
          self_._state = .finished
          mutableFinite.fail(with: error)
        }
      }
    } else {
      mutableFinite.fail(with: AsyncNinjaError.contextDeallocated)
    }
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

public typealias SimpleCachableValue<Value, Context: ExecutionContext> = CachableValue<Promise<Value>, Context>
public typealias ReportingCachableValue<PeriodicValue, FinalValue, Context: ExecutionContext> = CachableValue<Producer<PeriodicValue, FinalValue>, Context>
