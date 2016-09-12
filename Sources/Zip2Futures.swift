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

import Dispatch

public func zip<A, B>(_ futureA: Future<A>, _ futureB: Future<B>) -> Future<(A, B)> {
  let promise = Promise<(A, B)>()
  let sema = DispatchSemaphore(value: 1)
  var subvalueA: A? = nil
  var subvalueB: B? = nil

  let handlerA = futureA._onValue(executor: .immediate) { [weak promise] (localSubvalueA) in
    guard let promise = promise else { return }
    sema.wait()
    defer { sema.signal() }
    
    subvalueA = localSubvalueA
    if let localSubvalueB = subvalueB {
      promise.complete(with: (localSubvalueA, localSubvalueB))
    }
  }
  
  let handlerB = futureB._onValue(executor: .immediate) { [weak promise] (localSubvalueB) in
    guard let promise = promise else { return }
    sema.wait()
    defer { sema.signal() }
    
    subvalueB = localSubvalueB
    if let localSubvalueA = subvalueA {
      promise.complete(with: (localSubvalueA, localSubvalueB))
    }
  }
  
  promise.releasePool.insert(handlerA)
  promise.releasePool.insert(handlerB)
  
  return promise
}

public func zip<A, B>(_ futureA: Future<A>, _ valueB: B) -> Future<(A, B)> {
  return futureA.map(executor: .immediate) { ($0, valueB) }
}

public func zip<A, B>(_ futureA: FallibleFuture<A>, _ futureB: FallibleFuture<B>) -> FalliblePromise<(A, B)> {
  let promise = FalliblePromise<(A, B)>()
  let sema = DispatchSemaphore(value: 1)
  var subvalueA: A? = nil
  var subvalueB: B? = nil
  
  let handlerA = futureA._onValue(executor: .immediate) { [weak promise] (localSubvalueA) in
    guard let promise = promise else { return }
    sema.wait()
    defer { sema.signal() }
    
    localSubvalueA.onFailure(promise.fail(with:))
    localSubvalueA.onSuccess { localSubvalueA in
      subvalueA = localSubvalueA
      if let localSubvalueB = subvalueB {
        promise.succeed(with: (localSubvalueA, localSubvalueB))
      }
    }
  }
  
  let handlerB = futureB._onValue(executor: .immediate) { [weak promise] (localSubvalueB) in
    guard let promise = promise else { return }
    sema.wait()
    defer { sema.signal() }
    
    localSubvalueB.onFailure(promise.fail(with:))
    localSubvalueB.onSuccess { localSubvalueB in
      subvalueB = localSubvalueB
      if let localSubvalueA = subvalueA {
        promise.succeed(with: (localSubvalueA, localSubvalueB))
      }
    }
  }
  
  promise.releasePool.insert(handlerA)
  promise.releasePool.insert(handlerB)
  
  return promise
}

public func zip<A, B>(_ futureA: FallibleFuture<A>, _ futureB: Future<B>) -> FalliblePromise<(A, B)> {
  let promise = FalliblePromise<(A, B)>()
  let sema = DispatchSemaphore(value: 1)
  var subvalueA: A? = nil
  var subvalueB: B? = nil
  
  let handlerA = futureA._onValue(executor: .immediate) { [weak promise] (localSubvalueA) in
    guard let promise = promise else { return }
    sema.wait()
    defer { sema.signal() }
    
    localSubvalueA.onFailure(promise.fail(with:))
    localSubvalueA.onSuccess { localSubvalueA in
      subvalueA = localSubvalueA
      if let localSubvalueB = subvalueB {
        promise.succeed(with: (localSubvalueA, localSubvalueB))
      }
    }
  }
  
  let handlerB = futureB._onValue(executor: .immediate) { [weak promise] (localSubvalueB) in
    guard let promise = promise else { return }
    sema.wait()
    defer { sema.signal() }
    
    subvalueB = localSubvalueB
    if let localSubvalueA = subvalueA {
      promise.succeed(with: (localSubvalueA, localSubvalueB))
    }
  }
  
  promise.releasePool.insert(handlerA)
  promise.releasePool.insert(handlerB)
  
  return promise
}

public func zip<A, B>(_ futureA: FallibleFuture<A>, _ valueB: B) -> FallibleFuture<(A, B)> {
  return futureA.liftSuccess(executor: .immediate) { ($0, valueB) }
}
