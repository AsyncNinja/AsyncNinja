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

/// Merges two `Completing`s (e.g. `Future`s). `Completing` that completes first completes the result
///
/// - Parameters:
///   - a: first `Completing`
///   - b: second `Completing`
/// - Returns: future of merged arguments.
public func merge<A: Completing, B: Completing>(_ a: A, _ b: B) -> Future<A.Success>
  where A.Success == B.Success {
    let promise = Promise<A.Success>()
    promise.complete(with: a)
    promise.complete(with: b)
    return promise
}

/// Merges three `Completing`s (e.g. `Future`s). `Completing` that completes first completes the result
///
/// - Parameters:
///   - a: first
///   - b: second
///   - c: third
/// - Returns: future of merged arguments.
public func merge<A: Completing, B: Completing, C: Completing>(_ a: A, _ b: B, _ c: C) -> Future<A.Success>
  where A.Success == B.Success, A.Success == C.Success {
    let promise = Promise<A.Success>()
    promise.complete(with: a)
    promise.complete(with: b)
    promise.complete(with: c)
    return promise
}

/// Merges two `Completing`s (e.g. `Future`s). `Completing` that completes first completes the result
///
/// - Parameters:
///   - a: first
///   - b: second
/// - Returns: future of merged arguments.
public func merge<A: Completing, B: Completing>(_ a: A, _ b: B) -> Future<Either<A.Success, B.Success>> {
  let promise = Promise<Either<A.Success, B.Success>>()

  let handlerA = a.makeCompletionHandler(
    executor: .immediate
  ) { [weak promise] (completion, originalExecutor) in
    promise?.complete(completion.map(Either.left), from: originalExecutor)
  }
  promise._asyncNinja_retainHandlerUntilFinalization(handlerA)

  let handlerB = b.makeCompletionHandler(
    executor: .immediate
  ) { [weak promise] (completion, originalExecutor) in
    promise?.complete(completion.map(Either.right), from: originalExecutor)
  }

  promise._asyncNinja_retainHandlerUntilFinalization(handlerB)
  return promise
}
