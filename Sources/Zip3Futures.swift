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

public func zip<A, B, C>(_ futureA: Future<A>, _ futureB: Future<B>, _ futureC: Future<C>) -> Future<(A, B, C)> {
  let promise = Promise<(A, B, C)>()
  let sema = DispatchSemaphore(value: 1)
  var subvalueA: A? = nil
  var subvalueB: B? = nil
  var subvalueC: C? = nil
  
  let handlerA = futureA.makeFinalHandler(executor: .immediate) { [weak promise] (localSubvalueA) in
    guard let promise = promise else { return }
    sema.wait()
    defer { sema.signal() }
    
    subvalueA = localSubvalueA
    if let localSubvalueB = subvalueB, let localSubvalueC = subvalueC {
      promise.complete(with: (localSubvalueA, localSubvalueB, localSubvalueC))
    }
  }

  if let handlerA = handlerA {
    promise.releasePool.insert(handlerA)
  }

  let handlerB = futureB.makeFinalHandler(executor: .immediate) { [weak promise] (localSubvalueB) in
    guard let promise = promise else { return }
    sema.wait()
    defer { sema.signal() }
    
    subvalueB = localSubvalueB
    if let localSubvalueA = subvalueA, let localSubvalueC = subvalueC {
      promise.complete(with: (localSubvalueA, localSubvalueB, localSubvalueC))
    }
  }

  if let handlerB = handlerB {
    promise.releasePool.insert(handlerB)
  }

  let handlerC = futureC.makeFinalHandler(executor: .immediate) { [weak promise] (localSubvalueC) in
    guard let promise = promise else { return }
    sema.wait()
    defer { sema.signal() }
    
    subvalueC = localSubvalueC
    if let localSubvalueA = subvalueA, let localSubvalueB = subvalueB {
      promise.complete(with: (localSubvalueA, localSubvalueB, localSubvalueC))
    }
  }
  
  if let handlerC = handlerC {
    promise.releasePool.insert(handlerC)
  }

  return promise
}

public func zip<A, B, C>(_ futureA: FallibleFuture<A>, _ futureB: FallibleFuture<B>, _ futureC: FallibleFuture<C>) -> FallibleFuture<(A, B, C)> {
  let promise = FalliblePromise<(A, B, C)>()
  let sema = DispatchSemaphore(value: 1)
  var subvalueA: A? = nil
  var subvalueB: B? = nil
  var subvalueC: C? = nil
  
  let handlerA = futureA.makeFinalHandler(executor: .immediate) { [weak promise] (localSubvalueA) in
    guard let promise = promise else { return }
    sema.wait()
    defer { sema.signal() }
    
    localSubvalueA.onFailure(promise.fail(with:))
    localSubvalueA.onSuccess { localSubvalueA in
      subvalueA = localSubvalueA
      if let localSubvalueB = subvalueB, let localSubvalueC = subvalueC {
        promise.succeed(with: (localSubvalueA, localSubvalueB, localSubvalueC))
      }
    }
  }

  if let handlerA = handlerA {
    promise.releasePool.insert(handlerA)
  }

  let handlerB = futureB.makeFinalHandler(executor: .immediate) { [weak promise] (localSubvalueB) in
    guard let promise = promise else { return }
    sema.wait()
    defer { sema.signal() }
    
    localSubvalueB.onFailure(promise.fail(with:))
    localSubvalueB.onSuccess { localSubvalueB in
      subvalueB = localSubvalueB
      if let localSubvalueA = subvalueA, let localSubvalueC = subvalueC {
        promise.succeed(with: (localSubvalueA, localSubvalueB, localSubvalueC))
      }
    }
  }

  if let handlerB = handlerB {
    promise.releasePool.insert(handlerB)
  }

  let handlerC = futureC.makeFinalHandler(executor: .immediate) { [weak promise] (localSubvalueC) in
    guard let promise = promise else { return }
    sema.wait()
    defer { sema.signal() }
    
    localSubvalueC.onFailure(promise.fail(with:))
    localSubvalueC.onSuccess { localSubvalueC in
      subvalueC = localSubvalueC
      if let localSubvalueA = subvalueA, let localSubvalueB = subvalueB {
        promise.succeed(with: (localSubvalueA, localSubvalueB, localSubvalueC))
      }
    }
  }
  
  if let handlerC = handlerC {
    promise.releasePool.insert(handlerC)
  }

  return promise
}
