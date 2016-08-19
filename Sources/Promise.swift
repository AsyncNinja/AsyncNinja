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

import Foundation

public class Promise<T> : MutableFuture<T> {
  override public init() { }

  @discardableResult
  public func complete(with value: Value) -> Bool {
    var didCompleteThisTime = false

    self.tryUpdateAndMakeValue {
      didCompleteThisTime = true
      return value
    }

    return didCompleteThisTime
  }
}

public func future<T>(executor: Executor, block: @escaping () -> T) -> Future<T> {
  let promise = Promise<T>()
  executor.execute { promise.complete(with: block()) }
  return promise
}

public func future<T>(executor: Executor, block: @escaping () throws -> T) -> Future<Failable<T>> {
  let promise = Promise<Failable<T>>()
  executor.execute { promise.complete(with: failable(block: block)) }
  return promise
}
