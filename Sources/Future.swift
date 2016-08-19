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

/// Future is proxy for a value that will appear at some poing in future.
public class Future<T> : Channel {
  public typealias Value = T
  typealias Handler = FutureHandler<T>

  init() { }

  final public func map<T>(executor: Executor = .primary, _ transform: @escaping (Value) -> T) -> Future<T> {
    let promise = Promise<T>()
    let handler = FutureHandler(executor: executor) { value in
      promise.complete(with: transform(value))
    }
    self.add(handler: handler)
    return promise
  }

  final public func onValue(executor: Executor = .primary, block: @escaping (Value) -> Void) {
    let handler = FutureHandler(executor: executor, block: block)
    self.add(handler: handler)
  }

  func add(handler: FutureHandler<Value>) {
    fatalError() // abstract
  }
}


struct FutureHandler<T> {
  var executor: Executor
  var block: (T) -> Void

  func handle(value: T) {
    self.executor.execute { self.block(value) }
  }
}
