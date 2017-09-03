//
//  Copyright (c) 2017 Anton Mironov
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

// MARK: - try execute: non-contextual

/// Executes provided block multiple times until validation block returns true
///
/// - Parameters:
///   - executor: is `Executor` to execute block on
///   - validate: returns true if completion is fine
///     or false if it is not and block must be called again
///   - block: to call. Value returned from the block will be validated
/// - Returns: future of validated value
public func tryExecute<T>(
  executor: Executor = .primary,
  validate: @escaping (_ completion: Fallible<T>) -> Bool,
  _ block: @escaping () throws -> T) -> Future<T> {
  let promise = Promise<T>()
  _tryExecute(promise: WeakBox(promise),
              lockingBox: MutableBox(makeLocking()),
              executor: executor,
              validate: validate,
              block)
  return promise
}

/// Executes provided block and flattens result multiple times until validation block returns true
///
/// - Parameters:
///   - executor: is `Executor` to execute block on
///   - validate: returns true if completion is fine
///     or false if it is not and block must be called again
///   - block: to call. Value returned from the block will be flattented and validated
/// - Returns: future of validated value
public func tryFlatExecute<T>(
  executor: Executor = .primary,
  validate: @escaping (_ completion: Fallible<T>) -> Bool,
  _ block: @escaping () throws -> Future<T>) -> Future<T> {
  let promise = Promise<T>()
  _tryFlatExecute(promise: WeakBox(promise),
                  lockingBox: MutableBox(makeLocking()),
                  executor: executor,
                  validate: validate,
                  block)
  return promise
}

// MARK: - future makers: contextual

/// Executes provided block multiple times until validation block returns true
///
/// - Parameters:
///   - context: is `ExecutionContext` to perform transform on.
///     Instance of context will be passed as the first argument to the block.
///     Block will not be executed if executor was deallocated before execution,
///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
///   - executor: is `Executor` to override executor provided by context
///   - validate: returns true if completion is fine
///     or false if it is not and block must be called again
///   - block: to call. Value returned from the block will be validated
/// - Returns: future of validated value
public func tryExecute<T, C: ExecutionContext>(
  context: C,
  executor: Executor? = nil,
  validate: @escaping (_ strongContext: C, _ completion: Fallible<T>) -> Bool,
  _ block: @escaping (_ strongContext: C) throws -> T) -> Future<T> {
  let promise = Promise<T>()
  let weakContextBox = WeakBox(context)

  func _validate(completion: Fallible<T>) -> Bool {
    guard let context = weakContextBox.value else {
      return false
    }
    return validate(context, completion)
  }

  func _block() throws -> T {
    guard let context = weakContextBox.value else {
      throw AsyncNinjaError.contextDeallocated
    }
    return try block(context)
  }
  _tryExecute(promise: WeakBox(promise),
              lockingBox: MutableBox(makeLocking()),
              executor: executor ?? context.executor,
              validate: _validate, _block)
  return promise
}

/// Executes provided block and flattens result multiple times until validation block returns true
///
/// - Parameters:
///   - context: is `ExecutionContext` to perform transform on.
///     Instance of context will be passed as the first argument to the block.
///     Block will not be executed if executor was deallocated before execution,
///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
///   - executor: is `Executor` to override executor provided by context
///   - validate: returns true if completion is fine
///     or false if it is not and block must be called again
///   - block: to call. Value returned from the block will be flattented and validated
/// - Returns: future of validated value
public func tryFlatExecute<T, C: ExecutionContext>(
  context: C,
  executor: Executor? = nil,
  validate: @escaping (_ strongContext: C, _ completion: Fallible<T>) -> Bool,
  _ block: @escaping (_ strongContext: C) throws -> Future<T>) -> Future<T> {
  let promise = Promise<T>()
  let weakContextBox = WeakBox(context)

  func _validate(completion: Fallible<T>) -> Bool {
    guard let context = weakContextBox.value else {
      return false
    }

    return validate(context, completion)
  }

  func _block() throws -> Future<T> {
    guard let context = weakContextBox.value else {
      throw AsyncNinjaError.contextDeallocated
    }

    return try block(context)
  }
  _tryFlatExecute(promise: WeakBox(promise),
                  lockingBox: MutableBox(makeLocking()),
                  executor: executor ?? context.executor,
                  validate: _validate, _block)
  return promise
}

// MARK: - future makers: non-contextual

/// Executes provided block specified amount of times or until block returns value (not throws an error)
///
/// - Parameters:
///   - executor: is `Executor` to execute block on
///   - times: maximum amount of times the block will be executed
///   - block: to call. Value returned from the block will be validated
/// - Returns: future of validated value
public func tryExecute<T>(
  executor: Executor = .primary,
  times: Int,
  _ block: @escaping () throws -> T) -> Future<T> {
  var timesLeft = times
  func validate(completion: Fallible<T>) -> Bool {
    switch completion {
    case .success:
      return true
    case .failure:
      timesLeft -= 1
      return timesLeft == 0
    }
  }

  return tryExecute(executor: executor, validate: validate, block)
}

/// Executes provided block specified amount of times or until block returns future that completes successfully
///
/// - Parameters:
///   - executor: is `Executor` to execute block on
///   - times: maximum amount of times the block will be executed
///   - block: to call. Value returned from the block will be validated
/// - Returns: future of validated value
public func tryFlatExecute<T>(
  executor: Executor = .primary,
  times: Int,
  _ block: @escaping () throws -> Future<T>) -> Future<T> {
  var timesLeft = times
  func validate(completion: Fallible<T>) -> Bool {
    switch completion {
    case .success:
      return true
    case .failure:
      timesLeft -= 1
      return timesLeft == 0
    }
  }

  return tryFlatExecute(executor: executor, validate: validate, block)
}

// MARK: - future makers: contextual

/// Executes provided block specified amount of times or until block returns value (not throws an error)
///
/// - Parameters:
///   - context: is `ExecutionContext` to perform transform on.
///     Instance of context will be passed as the first argument to the block.
///     Block will not be executed if executor was deallocated before execution,
///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
///   - executor: is `Executor` to override executor provided by context
///   - times: maximum amount of times the block will be executed
///   - block: to call. Value returned from the block will be validated
/// - Returns: future of validated value
public func tryExecute<T, C: ExecutionContext>(
  context: C,
  executor: Executor? = nil,
  times: Int,
  _ block: @escaping (_ strongContext: C) throws -> T) -> Future<T> {
  var timesLeft = times
  func validate(context: C, completion: Fallible<T>) -> Bool {
    switch completion {
    case .success:
      return true
    case .failure:
      timesLeft -= 1
      return timesLeft == 0
    }
  }

  return tryExecute(context: context, executor: executor, validate: validate, block)
}

/// Executes provided block specified amount of times or until block returns future that completes successfully
///
/// - Parameters:
///   - context: is `ExecutionContext` to perform transform on.
///     Instance of context will be passed as the first argument to the block.
///     Block will not be executed if executor was deallocated before execution,
///     returned future will fail with `AsyncNinjaError.contextDeallocated` error
///   - executor: is `Executor` to override executor provided by context
///   - times: maximum amount of times the block will be executed
///   - block: to call. Value returned from the block will be validated
/// - Returns: future of validated value
public func tryFlatExecute<T, C: ExecutionContext>(
  context: C,
  executor: Executor? = nil,
  times: Int,
  _ block: @escaping (_ strongContext: C) throws -> Future<T>) -> Future<T> {
  var timesLeft = times
  func validate(context: C, completion: Fallible<T>) -> Bool {
    switch completion {
    case .success:
      return true
    case .failure:
      timesLeft -= 1
      return timesLeft == 0
    }
  }

  return tryFlatExecute(context: context, executor: executor, validate: validate, block)
}

// MARK: - internal helper methods

/// **internal use only**
private func _tryExecute<T>(
  promise: WeakBox<Promise<T>>,
  lockingBox: MutableBox<Locking>,
  executor: Executor = .primary,
  validate: @escaping (_ completion: Fallible<T>) -> Bool,
  _ block: @escaping () throws -> T
  ) {
  executor.execute(
    from: nil
  ) { (originalExecutor) in
    guard case .some = promise.value else { return }
    let completion = fallible(block: block)
    if lockingBox.value.locker({ validate(completion) }) {
      promise.value?.complete(completion, from: originalExecutor)
    } else {
      _tryExecute(promise: promise, lockingBox: lockingBox, executor: executor, validate: validate, block)
    }
  }
}

/// **internal use only**
private func _tryFlatExecute<T>(
  promise: WeakBox<Promise<T>>,
  lockingBox: MutableBox<Locking>,
  executor: Executor = .primary,
  validate: @escaping (_ completion: Fallible<T>) -> Bool,
  _ block: @escaping () throws -> Future<T>
  ) {
  executor.execute(
    from: nil
  ) { (originalExecutor) in
    guard case .some = promise.value else { return }
    do {
      let future = try block()
      let handler = future.makeCompletionHandler(executor: .primary) { (completion, originalExecutor) in
        if lockingBox.value.locker({ validate(completion) }) {
          promise.value?.complete(completion, from: originalExecutor)
        } else {
          _tryFlatExecute(promise: promise, lockingBox: lockingBox, executor: executor, validate: validate, block)
        }
      }
      promise.value?._asyncNinja_retainHandlerUntilFinalization(handler)

    } catch {
      let completion = Fallible<T>(failure: error)
      if lockingBox.value.locker({ validate(completion) }) {
        promise.value?.complete(completion, from: originalExecutor)
      } else {
        _tryFlatExecute(promise: promise, lockingBox: lockingBox, executor: executor, validate: validate, block)
      }
    }
  }
}
