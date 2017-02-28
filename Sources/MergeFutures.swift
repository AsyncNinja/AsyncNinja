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

/// Merges two futures. Future that completes first completes the result
///
/// - Parameters:
///   - futureA: first
///   - futureB: second
/// - Returns: future of combined results.
///   The future will complete right after completion of both futureA and futureB
public func merge<T>(
  _ futureA: Future<T>,
  _ futureB: Future<T>
  ) -> Future<T> {
  let promise = Promise<T>()
  promise.complete(with: futureA)
  promise.complete(with: futureB)
  return promise
}

/// Merges three futures. Future that completes first completes the result
///
/// - Parameters:
///   - futureA: first
///   - futureB: second
///   - futureC: third
/// - Returns: future of combined results.
///   The future will complete right after completion of both futureA and futureB
public func merge<T>(
  _ futureA: Future<T>,
  _ futureB: Future<T>,
  _ futureC: Future<T>
  ) -> Future<T> {
  let promise = Promise<T>()
  promise.complete(with: futureA)
  promise.complete(with: futureB)
  promise.complete(with: futureC)
  return promise
}

/// Merges two futures. Future that completes first completes the result
///
/// - Parameters:
///   - futureA: first
///   - futureB: second
/// - Returns: future of combined results.
///   The future will complete right after completion of both futureA and futureB
public func merge<A, B>(
  _ futureA: Future<A>,
  _ futureB: Future<B>
  ) -> Future<Either<A, B>> {
  let promise = Promise<Either<A, B>>()
  promise.complete(with: futureA.map(executor: .immediate) { .left($0) })
  promise.complete(with: futureB.map(executor: .immediate) { .right($0) })
  return promise
}
