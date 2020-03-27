//
//  Copyright (c) 2016-2020 Anton Mironov, Sergiy Vynnychenko
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

// MARK: - promise
/// Convenience constructor of Promise
/// Gives an access to an underlying Promise to a provided block
public func promise<T>(
  executor: Executor = .immediate,
  after timeout: Double = 0,
  cancellationToken: CancellationToken? = nil,
  _ block: @escaping (_ promise: Promise<T>) throws -> Void
) -> Promise<T> {
  let promise = Promise<T>()
  
  cancellationToken?.add(cancellable: promise)
  
  executor.execute(after: timeout) { [weak promise] (originalExecutor) in
    if cancellationToken?.isCancelled ?? false {
      promise?.cancel(from: originalExecutor)
    } else if let promise = promise {
      do    { try block(promise) }
      catch { promise.fail(error) }
    }
  }
  
  return promise
}

public extension ExecutionContext {
  // MARK: - ExecutionContext.promise()
  /// Convenience constructor of Promise
  /// Gives an access to an underlying Promise to a provided block
  func promise<T>(
    executor: Executor? = nil,
    after timeout: Double = 0,
    cancellationToken: CancellationToken? = nil,
    _ block: @escaping (_ context: Self, _ promise: Promise<T>) throws -> Void
  ) -> Promise<T> {
    
    return AsyncNinja.promise(
      executor: executor ?? self.executor,
      after: timeout,
      cancellationToken: cancellationToken
    ) { [weak self] promise  in
      guard let _self = self else { return }
      _self.addDependent(cancellable: promise)
      try block(_self, promise)
    }
  }
}

