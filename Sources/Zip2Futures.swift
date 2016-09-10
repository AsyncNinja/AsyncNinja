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

final class Zip2Futures<A, B> : MutableFuture<(A, B)> {
  private var _subvalueA: A?
  private var _subvalueB: B?

  init(_ futureA: Future<A>, _ futureB: Future<B>) {
    super.init()
    let handlerA = futureA._onValue(executor: .immediate) { [weak self] subvalueA in
      guard let self_ = self else { return }
      self_._subvalueA = subvalueA
      guard let value = self_._subvalueB.flatMap ({ (subvalueA, $0) }) else { return }
      self_.tryComplete(with: value)
    }
    let handlerB = futureB._onValue(executor: .immediate) { [weak self] subvalueB in
      guard let self_ = self else { return }
      self_._subvalueB = subvalueB
      guard let value = self_._subvalueA.flatMap ({ ($0, subvalueB) }) else { return }
      self_.tryComplete(with: value)
    }
    self.releasePool.insert(handlerA)
    self.releasePool.insert(handlerB)
  }
}

public func zip<A, B>(_ futureA: Future<A>, _ futureB: Future<B>) -> Future<(A, B)> {
  return Zip2Futures(futureA, futureB)
}

public func zip<A, B>(_ futureA: Future<A>, _ valueB: B) -> Future<(A, B)> {
  return futureA.map(executor: .immediate) { ($0, valueB) }
}
