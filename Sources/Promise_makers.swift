//
//  Promise_makers.swift
//  AsyncNinja
//
//  Created by Loki on 3/25/19.
//

import Foundation

public func promise<T>(
  executor: Executor = .immediate,
  after timeout: Double = 0,
  cancellationToken: CancellationToken?,
  _ block: @escaping (_ promise: Promise<T>) throws -> Void) -> Promise<T> {
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

public func promise<C: ExecutionContext, T>(
  context: C,
  executor: Executor? = nil,
  after timeout: Double = 0,
  cancellationToken: CancellationToken?,
  _ block: @escaping (_ promise: Promise<T>) throws -> Void) -> Promise<T> {
  
  return promise(executor: executor ?? context.executor,
                 after: timeout,
                 cancellationToken: cancellationToken) { promise in
                  context.addDependent(cancellable: promise)
                  try block(promise)
  }
}
