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

/// Combines three futures
///
/// - Parameters:
///   - futureA: first
///   - futureB: second
///   - futureC: third
/// - Returns: future of combined results.
///   The future will complete right after completion of futureA, futureB, futureC
public func zip<A, B, C>(_ futureA: Future<A>,
                _ futureB: Future<B>,
                _ futureC: Future<C>) -> Future<(A, B, C)> {
  // Test: ZipFuturesTest.test3Simple
  // Test: ZipFuturesTest.test3Delayed
  // Test: ZipFuturesTest.test3Failure
  // Test: ZipFuturesTest.test3Lifetime
  let promise = Promise<(A, B, C)>()
  var locking = makeLocking()
  var subvalueA: A? = nil
  var subvalueB: B? = nil
  var subvalueC: C? = nil
  
  let handlerA = futureA.makeCompletionHandler(executor: .immediate)
  {
    [weak promise] (localSubvalueA, originalExecutor) in
    guard let promise = promise else { return }
    locking.lock()
    defer { locking.unlock() }

    localSubvalueA.onFailure {
      promise.fail(with: $0, from: originalExecutor)
    }
    localSubvalueA.onSuccess { localSubvalueA in
      subvalueA = localSubvalueA
      if let localSubvalueB = subvalueB, let localSubvalueC = subvalueC {
        promise.succeed(with: (localSubvalueA, localSubvalueB, localSubvalueC),
                        from: originalExecutor)
      }
    }
  }

  promise.insertHandlerToReleasePool(handlerA)

  let handlerB = futureB.makeCompletionHandler(executor: .immediate) {
    [weak promise] (localSubvalueB, originalExecutor) in
    guard let promise = promise else { return }
    locking.lock()
    defer { locking.unlock() }

    localSubvalueB.onFailure {
      promise.fail(with: $0, from: originalExecutor)
    }
    localSubvalueB.onSuccess { localSubvalueB in
      subvalueB = localSubvalueB
      if let localSubvalueA = subvalueA, let localSubvalueC = subvalueC {
        promise.succeed(with: (localSubvalueA, localSubvalueB, localSubvalueC),
                        from: originalExecutor)
      }
    }
  }

  promise.insertHandlerToReleasePool(handlerB)

  let handlerC = futureC.makeCompletionHandler(executor: .immediate)
  {
    [weak promise] (localSubvalueC, originalExecutor) in
    guard let promise = promise else { return }
    locking.lock()
    defer { locking.unlock() }
    
    localSubvalueC.onFailure {
      promise.fail(with: $0, from: originalExecutor)
    }
    localSubvalueC.onSuccess { localSubvalueC in
      subvalueC = localSubvalueC
      if let localSubvalueA = subvalueA, let localSubvalueB = subvalueB {
        promise.succeed(with: (localSubvalueA, localSubvalueB, localSubvalueC),
                        from: originalExecutor)
      }
    }
  }
  
  promise.insertHandlerToReleasePool(handlerC)

  return promise
}

/// Combines two futures and one value
///
/// - Parameters:
///   - futureA: first
///   - futureB: second
///   - valueC: third
/// - Returns: future of combined results.
///   The future will complete right after completion of futureA and futureB.
public func zip<A, B, C>(_ futureA: Future<A>,
                _ futureB: Future<B>,
                _ valueC: C) -> Future<(A, B, C)> {
  // Test: ZipFuturesTest.test3Constant
  return zip(futureA, futureB).map(executor: .immediate) { ($0, $1, valueC) }
}

/// Combines one future and two value
///
/// - Parameters:
///   - futureA: first
///   - valueB: second
///   - valueC: third
/// - Returns: future of combined results. 
///   The future will complete right after completion of futureA.
public func zip<A, B, C>(_ futureA: Future<A>,
                _ valueB: B,
                _ valueC: C) -> Future<(A, B, C)> {
  // Test: ZipFuturesTest.test3Constants
  return futureA.map(executor: .immediate) { ($0, valueB, valueC) }
}
