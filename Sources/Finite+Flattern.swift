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

public extension Finite where FinalValue : Finite {
  /// flatterns combination of two nested unfaillable futures to a signle unfallible one
  final func flattern() -> Future<FinalValue.FinalValue> {
    let promise = Promise<FinalValue.FinalValue>()

    let handler = self.makeFinalHandler(executor: .immediate) { [weak promise] (future) in
      guard let promise = promise else { return }
      let handler = (future as! Future<FinalValue.FinalValue>)
        .makeFinalHandler(executor: .immediate) { [weak promise] (final) in
        promise?.complete(with: final)
      }
      if let handler = handler {
        promise.insertToReleasePool(handler)
      }
    }

    if let handler = handler {
      promise.insertToReleasePool(handler)
    }

    return promise
  }
}

public extension Finite where FinalValue : _Fallible, FinalValue.Success : Finite {
  /// flatterns combination of nested fallible and unfaillable futures to a signle fallible one
  final func flattern() -> FallibleFuture<FinalValue.Success.FinalValue> {
    let promise = FalliblePromise<FinalValue.Success.FinalValue>()

    let handler = self.makeFinalHandler(executor: .immediate) { [weak promise] (futureFallible) in
      guard let promise = promise else { return }
      futureFallible.onFailure(promise.fail(with:))
      futureFallible.onSuccess { future in
        let handler = (future as! Future<FinalValue.Success.FinalValue>)
          .makeFinalHandler(executor: .immediate) { [weak promise] (final: FinalValue.Success.FinalValue) -> Void in
          promise?.succeed(with: final)
        }

        if let handler = handler {
          promise.insertToReleasePool(handler)
        }
      }
    }

    if let handler = handler {
      promise.insertToReleasePool(handler)
    }
    return promise
  }
}

public extension Finite where FinalValue : _Fallible, FinalValue.Success : Finite, FinalValue.Success.FinalValue : _Fallible {
  /// flatterns combination of nested two faillable futures to a signle fallible one
  final func flattern() -> Future<FinalValue.Success.FinalValue> {
    let promise = Promise<FinalValue.Success.FinalValue>()

    let handler = self.makeFinalHandler(executor: .immediate) { [weak promise] (futureFallible) in
      guard let promise = promise else { return }
      futureFallible.onFailure(promise.fail(with:))
      futureFallible.onSuccess { future in
        let handler = (future as! Future<FinalValue.Success.FinalValue>)
          .makeFinalHandler(executor: .immediate) { [weak promise] (value: FinalValue.Success.FinalValue) -> Void in
          promise?.complete(with: value)
        }
        if let handler = handler {
          promise.insertToReleasePool(handler)
        }
      }
    }

    if let handler = handler {
      promise.insertToReleasePool(handler)
    }
    return promise
  }
}
