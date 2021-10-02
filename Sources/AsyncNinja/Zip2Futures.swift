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

/// Combines two futures
///
/// - Parameters:
///   - futureA: first
///   - futureB: second
/// - Returns: future of combined results.
///   The future will complete right after completion of both futureA and futureB
public func zip<A, B>(
  _ futureA: Future<A>,
  _ futureB: Future<B>
  ) -> Future<(A, B)> {
  // Test: ZipFuturesTest.test2Simple
  // Test: ZipFuturesTest.test2Delayed
  // Test: ZipFuturesTest.test2Failure
  // Test: ZipFuturesTest.test2Lifetime
  let promise = Promise<(A, B)>()
  let locking = makeLocking()
  var subvalueA: A?
  var subvalueB: B?

  let handlerA = futureA.makeCompletionHandler(
    executor: .immediate
  ) { [weak promise] (localSubvalueA, originalExecutor) in
    guard let promise = promise else { return }
    locking.lock()
    defer { locking.unlock() }

    localSubvalueA.onFailure {
      promise.fail($0, from: originalExecutor)
    }
    localSubvalueA.onSuccess { localSubvalueA in
      subvalueA = localSubvalueA
      if let localSubvalueB = subvalueB {
        promise.succeed((localSubvalueA, localSubvalueB),
                        from: originalExecutor)
      }
    }
  }

  promise._asyncNinja_retainHandlerUntilFinalization(handlerA)

  let handlerB = futureB.makeCompletionHandler(
    executor: .immediate
  ) { [weak promise] (localSubvalueB, originalExecutor) in
    guard let promise = promise else { return }
    locking.lock()
    defer { locking.unlock() }

    localSubvalueB.onFailure {
      promise.fail($0, from: originalExecutor)
    }
    localSubvalueB.onSuccess { localSubvalueB in
      subvalueB = localSubvalueB
      if let localSubvalueA = subvalueA {
        promise.succeed((localSubvalueA, localSubvalueB),
                        from: originalExecutor)
      }
    }
  }

  promise._asyncNinja_retainHandlerUntilFinalization(handlerB)

  return promise
}

/// Combines future and value
///
/// - Parameters:
///   - futureA: first
///   - valueB: second
/// - Returns: future of combined results.
///   The future will complete right after completion of futureA.
public func zip<A, B>(_ futureA: Future<A>, _ valueB: B) -> Future<(A, B)> {
  // Test: ZipFuturesTest.test2Constant
  return futureA.map(executor: .immediate) { ($0, valueB) }
}
