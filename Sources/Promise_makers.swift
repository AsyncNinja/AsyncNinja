//
//  Promise_makers.swift
//  AsyncNinja
//
//  Created by Sergiy Vynnychenko on 3/25/19.
//

import Foundation

// MARK: - promise
/// Convenience constructor of Promise
/// Gives an access to an underlying Promise to a provided block
public func promise<T>(
  executor: Executor = .immediate,
  after timeout: Double = 0,
  cancellationToken: CancellationToken? = nil,
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

public extension ExecutionContext {
  // MARK: - ExecutionContext.promise()
  /// Convenience constructor of Promise
  /// Gives an access to an underlying Promise to a provided block
  func promise<T>(executor: Executor? = nil,
               after timeout: Double = 0,
               cancellationToken: CancellationToken? = nil,
               _ block: @escaping (_ context: Self, _ promise: Promise<T>) throws -> Void) -> Promise<T> {
    
    return AsyncNinja.promise(executor: executor ?? self.executor, after: timeout, cancellationToken: cancellationToken)
      { [weak self] promise  in
        guard let _self = self else { return }
        _self.addDependent(cancellable: promise)
        try block(_self, promise)
      }
    }
}

