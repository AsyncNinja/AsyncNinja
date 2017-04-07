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

public func tryExecute<T>(
  executor: Executor = .primary,
  until: @escaping (_ completion: Fallible<T>) -> Bool,
  _ block: @escaping () throws -> T) -> Future<T>
{
  let promise = Promise<T>()
  _tryExecute(promise: WeakBox(promise),
              lockingBox: MutableBox(makeLocking()),
              executor: executor,
              until: until,
              block)
  return promise
}

public func tryFlatExecute<T>(
  executor: Executor = .primary,
  until: @escaping (_ completion: Fallible<T>) -> Bool,
  _ block: @escaping () throws -> Future<T>) -> Future<T>
{
  let promise = Promise<T>()
  _tryFlatExecute(promise: WeakBox(promise),
                  lockingBox: MutableBox(makeLocking()),
                  executor: executor,
                  until: until,
                  block)
  return promise
}

// MARK: - future makers: contextual

public func tryExecute<T, C: ExecutionContext>(
  context: C,
  executor: Executor? = nil,
  until: @escaping (_ strongContext: C, _ completion: Fallible<T>) -> Bool,
  _ block: @escaping (_ strongContext: C) throws -> T) -> Future<T>
{
  let promise = Promise<T>()
  _tryExecute(promise: WeakBox(promise),
              lockingBox: MutableBox(makeLocking()),
              executor: executor ?? context.executor,
              until:
    { [weak context] (completion) in
      if let strongContext = context {
        return until(strongContext, completion)
      } else {
        return false
      }
    })
  { [weak context] in
    guard let strongContext = context else { throw AsyncNinjaError.contextDeallocated }
    return try block(strongContext)
  }
  return promise
}

public func tryFlatExecute<T, C: ExecutionContext>(
  context: C,
  executor: Executor? = nil,
  until: @escaping (_ strongContext: C, _ completion: Fallible<T>) -> Bool,
  _ block: @escaping (_ strongContext: C) throws -> Future<T>) -> Future<T>
{
  let promise = Promise<T>()
  _tryFlatExecute(promise: WeakBox(promise),
                  lockingBox: MutableBox(makeLocking()),
                  executor: executor ?? context.executor,
                  until:
    { [weak context] (completion) in
      if let strongContext = context {
        return until(strongContext, completion)
      } else {
        return false
      }
    })
  { [weak context] in
    guard let strongContext = context else { throw AsyncNinjaError.contextDeallocated }
    return try block(strongContext)
  }
  return promise
}

// MARK: - future makers: non-contextual

public func tryExecute<T>(
  executor: Executor = .primary,
  times: Int,
  _ block: @escaping () throws -> T) -> Future<T>
{
  var timesLeft = times
  func until(completion: Fallible<T>) -> Bool {
    switch completion {
    case .success:
      return true
    case .failure:
      timesLeft -= 1
      return timesLeft == 0
    }
  }

  return tryExecute(executor: executor, until: until, block)
}

public func tryFlatExecute<T>(
  executor: Executor = .primary,
  times: Int,
  _ block: @escaping () throws -> Future<T>) -> Future<T>
{
  var timesLeft = times
  func until(completion: Fallible<T>) -> Bool {
    switch completion {
    case .success:
      return true
    case .failure:
      timesLeft -= 1
      return timesLeft == 0
    }
  }

  return tryFlatExecute(executor: executor, until: until, block)
}

// MARK: - future makers: contextual

public func tryExecute<T, C: ExecutionContext>(
  context: C,
  executor: Executor? = nil,
  times: Int,
  _ block: @escaping (_ strongContext: C) throws -> T) -> Future<T>
{
  var timesLeft = times
  func until(context: C, completion: Fallible<T>) -> Bool {
    switch completion {
    case .success:
      return true
    case .failure:
      timesLeft -= 1
      return timesLeft == 0
    }
  }

  return tryExecute(context: context, executor: executor, until: until, block)
}

public func tryFlatExecute<T, C: ExecutionContext>(
  context: C,
  executor: Executor? = nil,
  times: Int,
  _ block: @escaping (_ strongContext: C) throws -> Future<T>) -> Future<T>
{
  var timesLeft = times
  func until(context: C, completion: Fallible<T>) -> Bool {
    switch completion {
    case .success:
      return true
    case .failure:
      timesLeft -= 1
      return timesLeft == 0
    }
  }

  return tryFlatExecute(context: context, executor: executor, until: until, block)
}

// MARK: - internal helper methods

/// **internal use only**
private func _tryExecute<T>(
  promise: WeakBox<Promise<T>>,
  lockingBox: MutableBox<Locking>,
  executor: Executor = .primary,
  until: @escaping (_ completion: Fallible<T>) -> Bool,
  _ block: @escaping () throws -> T)
{
  executor.execute(from: nil) {
    (originalExecutor) in
    guard case .some = promise.value else { return }
    let completion = fallible(block: block)
    if lockingBox.value.locker({ until(completion) }) {
      promise.value?.complete(completion, from: originalExecutor)
    } else {
      _tryExecute(promise: promise, lockingBox: lockingBox, executor: executor, until: until, block)
    }
  }
}

/// **internal use only**
private func _tryFlatExecute<T>(
  promise: WeakBox<Promise<T>>,
  lockingBox: MutableBox<Locking>,
  executor: Executor = .primary,
  until: @escaping (_ completion: Fallible<T>) -> Bool,
  _ block: @escaping () throws -> Future<T>)
{
  executor.execute(from: nil) {
    (originalExecutor) in
    guard case .some = promise.value else { return }
    do {
      let future = try block()
      let handler = future.makeCompletionHandler(executor: .primary) { (completion, originalExecutor) in
        if lockingBox.value.locker({ until(completion) }) {
          promise.value?.complete(completion, from: originalExecutor)
        } else {
          _tryFlatExecute(promise: promise, lockingBox: lockingBox, executor: executor, until: until, block)
        }
      }
      promise.value?._asyncNinja_retainHandlerUntilFinalization(handler)

    } catch {
      let completion = Fallible<T>(failure: error)
      if lockingBox.value.locker({ until(completion) }) {
        promise.value?.complete(completion, from: originalExecutor)
      } else {
        _tryFlatExecute(promise: promise, lockingBox: lockingBox, executor: executor, until: until, block)
      }
    }
  }
}
