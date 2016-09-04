//
//  Future+ExecutionContext.swift
//  FunctionalConcurrency
//
//  Created by Anton Mironov on 04.09.16.
//
//

import Foundation

public extension Future {
  final func map<U: ExecutionContext, V>(context: U?, _ transform: @escaping (Value, U) throws -> V) -> FallibleFuture<V> {
    let promise = Promise<Fallible<V>>()
    weak var weakContext = context
    let handler = FutureHandler<Value>(executor: .immediate) { value in
      if let context = weakContext {
        context.executor.execute {
          promise.complete(with: fallible { try transform(value, context) })
        }
      } else {
        promise.complete(with: Fallible(failure: ConcurrencyError.ownedDeallocated))
      }
    }
    self.add(handler: handler)
    return promise
  }

  final func onValue<U: ExecutionContext>(context: U, block: @escaping (Value, U) -> Void) {
    weak var weakContext = context
    let handler = FutureHandler<Value>(executor: Executor.immediate) { value in
      if let context = weakContext {
        context.executor.execute { block(value, context) }
      }
    }
    self.add(handler: handler)
  }
}

public extension Future where T : _Fallible {

  final public func liftSuccess<T, U: ExecutionContext>(context: U?, transform: @escaping (Success, U) throws -> T) -> FallibleFuture<T> {
    let promise = FalliblePromise<T>()
    weak var weakContext = context

    self.onValue(executor: .immediate) {
      guard let successValue = $0.successValue else {
        promise.complete(with: Fallible(failure: $0.failureValue!))
        return
      }

      guard let context = weakContext else {
        promise.complete(with: Fallible(failure: ConcurrencyError.ownedDeallocated))
        return
      }

      context.executor.execute {
        let transformedValue = fallible { try transform(successValue, context) }
        promise.complete(with: transformedValue)
      }
    }

    return promise
  }

  final public func onSuccess<U: ExecutionContext>(context: U?, block: @escaping (Success, U) -> Void) {
    weak var weakContext = context

    self.onValue(executor: .immediate) {
      guard
        let successValue = $0.successValue,
        let context = weakContext
        else { return }

      context.executor.execute {
        block(successValue, context)
      }
    }
  }

  final public func liftFailure<U: ExecutionContext>(context: U?, transform: @escaping (Error, U) throws -> Success) -> FallibleFuture<Success> {
    let promise = FalliblePromise<Success>()
    weak var weakContext = context

    self.onValue(executor: .immediate) {
      guard let failureValue = $0.failureValue else {
        promise.complete(with: Fallible(success: $0.successValue!))
        return
      }

      guard let context = weakContext else {
        promise.complete(with: Fallible(failure: ConcurrencyError.ownedDeallocated))
        return
      }

      context.executor.execute {
        let transformedValue = fallible { try transform(failureValue, context) }
        promise.complete(with: transformedValue)
      }
    }

    return promise
  }

  final public func onFailure<U: ExecutionContext>(context: U?, block: @escaping (Error, U) -> Void) {
    weak var weakContext = context

    self.onValue(executor: .immediate) {
      guard let failureValue = $0.failureValue, let context = weakContext else { return }
      context.executor.execute {
        block(failureValue, context)
      }
    }
  }
}
