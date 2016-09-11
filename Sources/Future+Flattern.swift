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

public extension Future where T : _Future {
  /// flatterns combination of two nested unfaillable futures to a signle unfallible one
  final func flattern() -> Future<T.Value> {
    let promise = Promise<T.Value>()

    let handler = self._onValue(executor: .immediate) { [weak promise] (future) in
      guard let promise = promise else { return }
      let handler = future._onValue(executor: .immediate) { [weak promise] (value) in
        promise?.complete(with: value)
      }
      promise.releasePool.insert(handler)
    }

    promise.releasePool.insert(handler)

    return promise
  }
}

public extension Future where T : _Fallible, T.Success : _Future {
  /// flatterns combination of nested fallible and unfaillable futures to a signle fallible one
  final func flattern() -> FallibleFuture<T.Success.Value> {
    let promise = FalliblePromise<T.Success.Value>()

    let handler = self._onValue(executor: .immediate) { [weak promise] (futureFallible) in
      guard let promise = promise else { return }
      futureFallible.onFailure(promise.fail(with:))
      futureFallible.onSuccess { future in
        let handler = future._onValue(executor: .immediate) { [weak promise] (value: T.Success.Value) -> Void in
          promise?.succeed(with: value)
        }
        promise.releasePool.insert(handler)
      }
    }

    promise.releasePool.insert(handler)
    return promise
  }
}

public extension Future where T : _Fallible, T.Success : _Future, T.Success.Value : _Fallible {
  /// flatterns combination of nested two faillable futures to a signle fallible one
  final func flattern() -> Future<T.Success.Value> {
    let promise = Promise<T.Success.Value>()

    let handler = self._onValue(executor: .immediate) { [weak promise] (futureFallible) in
      guard let promise = promise else { return }
      futureFallible.onFailure(promise.fail(with:))
      futureFallible.onSuccess { future in
        let handler = future._onValue(executor: .immediate) { [weak promise] (value: T.Success.Value) -> Void in
          promise?.complete(with: value)
        }
        promise.releasePool.insert(handler)
      }
    }

    promise.releasePool.insert(handler)
    return promise
  }
}
