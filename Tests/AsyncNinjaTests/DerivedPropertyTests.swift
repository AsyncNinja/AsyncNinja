//
//  Copyright (c) 2018 Anton Mironov
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

import XCTest
import Dispatch
@testable import AsyncNinja
#if os(Linux)
import Glibc
#endif

class DerivedPropertyTests: XCTestCase {

  static let allTests = [
    ("testSimple", testSimple)
    ]

  func testSimple() {
    let actor = TestActor<Int, String, Int?>(aValue: 1, bValue: "one", cValue: nil)
    XCTAssert(actor.zValue == (1, "one", nil))
    actor.aValue = 2
    XCTAssert(actor.zValue == (2, "one", nil))
    actor.aValue = 3
    actor.bValue = "two"
    actor.cValue = 10
    XCTAssert(actor.zValue == (3, "two", 10))
  }

  class TestActor<A, B, C>: ExecutionContext, ReleasePoolOwner, CustomKVOUpdatableSupport, CustomKVOUpdatingSupport {
    var executor: Executor { return .main }
    let releasePool = ReleasePool()

    private var _aValue: DynamicProperty<A>!
    var aValue: A {
      get { return _aValue.value }
      set { _aValue.value = newValue }
    }

    private var _bValue: DynamicProperty<B>!
    var bValue: B {
      get { return _bValue.value }
      set { _bValue.value = newValue }
    }

    private var _cValue: DynamicProperty<C>!
    var cValue: C {
      get { return _cValue.value }
      set { _cValue.value = newValue }
    }

    private var _zValue: Channel<(A, B, C), Void>!
    var zValue: (A, B, C) { return _zValue.latestUpdate! }

    init(aValue: A, bValue: B, cValue: C) {
      _aValue = makeDynamicProperty(aValue)
      _bValue = makeDynamicProperty(bValue)
      _cValue = makeDynamicProperty(cValue)
      _zValue = makeDerivedProperty(for: [
        \TestActor<A, B, C>.aValue,
        \TestActor<A, B, C>.bValue,
        \TestActor<A, B, C>.cValue
        ]) { (valuesProvider) -> (A, B, C) in
          return (
            valuesProvider[\.aValue],
            valuesProvider[\.bValue],
            valuesProvider[\.cValue]
            )
      }
    }

    func customUpdatable(forKeyPath keyPath: AnyKeyPath) -> BaseProducer<Any, Void>? {
      switch keyPath {
      case \TestActor<A, B, C>.aValue: return _aValue.staticCastProducer()
      case \TestActor<A, B, C>.bValue: return _bValue.staticCastProducer()
      case \TestActor<A, B, C>.cValue: return _cValue.staticCastProducer()
      default: return nil
      }
    }

    func customUpdating(forKeyPath keyPath: AnyKeyPath) -> Channel<Any, Void>? {
      switch keyPath {
      case \TestActor<A, B, C>.zValue: return _zValue.staticCast()
      default: return nil
      }
    }
  }
}
