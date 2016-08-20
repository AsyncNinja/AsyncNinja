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

final class Zip3Futures<A, B, C> : MutableFuture<(A, B, C)> {
  private var _subvalueA: A?
  private var _subvalueB: B?
  private var _subvalueC: C?

  init(_ futureA: Future<A>, _ futureB: Future<B>, _ futureC: Future<C>) {
    super.init()
    futureA.onValue(executor: .immediate) { [weak self] (subvalueA) in
      guard let self_ = self else { return }

      self_.tryUpdateAndMakeValue {
        self_._subvalueA = subvalueA
        if let subvalueB = self_._subvalueB, let subvalueC = self_._subvalueC {
          return (subvalueA, subvalueB, subvalueC)
        } else {
          return nil
        }
      }
    }

    futureB.onValue(executor: .immediate) { [weak self] (subvalueB) in
      guard let self_ = self else { return }

      self_.tryUpdateAndMakeValue {
        self_._subvalueB = subvalueB
        if let subvalueA = self_._subvalueA, let subvalueC = self_._subvalueC {
          return (subvalueA, subvalueB, subvalueC)
        } else {
          return nil
        }
      }
    }

    futureC.onValue(executor: .immediate) { [weak self] (subvalueC) in
      guard let self_ = self else { return }

      self_.tryUpdateAndMakeValue {
        self_._subvalueC = subvalueC
        if let subvalueA = self_._subvalueA, let subvalueB = self_._subvalueB {
          return (subvalueA, subvalueB, subvalueC)
        } else {
          return nil
        }
      }
    }
  }
}

public func zip<A, B, C>(_ futureA: Future<A>, _ futureB: Future<B>, _ futureC: Future<C>) -> Future<(A, B, C)> {
  return Zip3Futures(futureA, futureB, futureC)
}
