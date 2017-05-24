//
//  Copyright (c) 2016-2017 Anton Mironov
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

class EitherTests: XCTestCase {

  static let allTests = [
    ("testLeft", testLeft),
    ("testRight", testRight),
    ("testEquals", testEquals),
    ("testChannelEvent", testChannelEvent)
    ]

  func testLeft() {
    let either: Either<Any, Any> = .left(1)
    XCTAssertEqual(either.left as! Int, 1)
    XCTAssertNil(either.right)
    XCTAssertEqual(either.mapLeft { ($0 as! Int) * 2 }.left, 2)
    XCTAssertEqual(either.mapRight { ($0 as! String) + "!" }.left as! Int, 1)
    XCTAssertEqual(either.description, "left(1)")
    XCTAssertEqual(either.debugDescription, "left<Any, Any>(1)")

    let castedEither: Either<Int, String> = either.staticCast()
    XCTAssertEqual(castedEither.left, 1)
  }

  func testRight() {
    let either: Either<Any, Any> = .right("success")
    XCTAssertEqual(either.right as! String, "success")
    XCTAssertNil(either.left)
    XCTAssertEqual(either.mapRight { ($0 as! String) + "!" }.right, "success!")
    XCTAssertEqual(either.mapLeft { ($0 as! Int) * 2 }.right as! String, "success")
    XCTAssertEqual(either.description, "right(success)")
    XCTAssertEqual(either.debugDescription, "right<Any, Any>(success)")

    let castedEither: Either<Int, String> = either.staticCast()
    XCTAssertEqual(castedEither.right, "success")
  }

  func testEquals() {
    let a = Either<Int, String>.left(1)
    let b = Either<Int, String>.left(2)
    let c = Either<Int, String>.right("hello")
    let d = Either<Int, String>.right("bye")

    XCTAssert(a == a)
    XCTAssert(a != b)
    XCTAssert(a != c)
    XCTAssert(a != d)

    XCTAssert(c != a)
    XCTAssert(c != b)
    XCTAssert(c == c)
    XCTAssert(c != d)
  }

  func testChannelEvent() {
    if case let .update(value) = ChannelEvent<Int, String>.update(1) {
      XCTAssertEqual(value, 1)
    } else {
      XCTFail()
    }

    if case let .completion(.success(value)) = ChannelEvent<Int, String>.completion(.success("success")) {
      XCTAssertEqual(value, "success")
    } else {
      XCTFail()
    }

    if case let .completion(.success(value)) = ChannelEvent<Int, String>.success("success") {
      XCTAssertEqual(value, "success")
    } else {
      XCTFail()
    }

    if case .completion(.failure) = ChannelEvent<Int, String>.completion(.failure(TestError.testCode)) {
    } else {
      XCTFail()
    }

    if case .completion(.failure) = ChannelEvent<Int, String>.failure(TestError.testCode) {
    } else {
      XCTFail()
    }

    let castedA: ChannelEvent<Int, String> = ChannelEvent<Any, Any>.update(1).staticCast()
    if case let .update(value) = castedA {
      XCTAssertEqual(value, 1)
    } else {
      XCTFail()
    }

    let castedB: ChannelEvent<Int, String> = ChannelEvent<Any, Any>.success("success").staticCast()
    if case let .completion(.success(value)) = castedB {
      XCTAssertEqual(value, "success")
    } else {
      XCTFail()
    }
  }
}
