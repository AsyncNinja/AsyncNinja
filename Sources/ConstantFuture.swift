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

/// A future that has been initialized as completed
final class ConstantFuture<FinalValue> : Future<FinalValue> {
  private var _value: Value
  override public var finalValue: Value? { return _value }
  let releasePool = ReleasePool()

  init(value: Value) {
    _value = value
  }

  override public func makeFinalHandler(executor: Executor,
                                        block: @escaping (Fallible<FinalValue>) -> Void) -> FinalHandler? {
    executor.execute { block(self._value) }
    return nil
  }
  
  override func insertToReleasePool(_ releasable: Releasable) {
    /* do nothing because future was created as complete */
  }
}

/// Makes completed future
///
/// - Parameter value: value to complete future with
/// - Returns: completed future
public func future<T>(value: Fallible<T>) -> Future<T> {
  return ConstantFuture(value: value)
}

/// Makes succeeded future
///
/// - Parameter success: success value to complete future with
/// - Returns: succeeded future
public func future<T>(success: T) -> Future<T> {
  return ConstantFuture(value: Fallible(success: success))
}

/// Makes failed future
///
/// - Parameter failure: failure value (Error) to complete future with
/// - Returns: failed future
public func future<T>(failure: Swift.Error) -> Future<T> {
  return ConstantFuture(value: Fallible(failure: failure))
}

/// Makes cancelled future (shorthand to `future(failure: AsyncNinjaError.cancelled)`)
///
/// - Returns: cancelled future
public func cancelledFuture<T>() -> Future<T> {
    return future(failure: AsyncNinjaError.cancelled)
}
