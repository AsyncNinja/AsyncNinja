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

class ExecutorTests: XCTestCase {

  static let allTests = [
    ("testPrimary", testPrimary),
    ("testUserInteractive", testUserInteractive),
    ("testUserInitiated", testUserInitiated),
    ("testDefault", testDefault),
    ("testUtility", testUtility),
//    ("testBackground", testBackground),
    ("testImmediate", testImmediate),
    ("testCustomQueue", testCustomQueue),
    ("testCustomQoS", testCustomQoS),
    ("testCustomHandler", testCustomHandler)
  ]

  func testPrimary() {
    let expectation = self.expectation(description: "executed")
    Executor.primary.execute(from: nil) { _ in
      expectation.fulfill()
      assert(qos: .default)
    }
    self.waitForExpectations(timeout: 0.1)
  }

  func testUserInteractive() {
    let expectation = self.expectation(description: "executed")
    Executor.userInteractive.execute(from: nil) { _ in
      expectation.fulfill()
      assert(qos: .userInteractive)
    }
    self.waitForExpectations(timeout: 0.1)
  }

  func testUserInitiated() {
    let expectation = self.expectation(description: "executed")
    Executor.userInitiated.execute(from: nil) { _ in
      expectation.fulfill()
      assert(qos: .userInitiated)
    }
    self.waitForExpectations(timeout: 0.1)
  }

  func testDefault() {
    let expectation = self.expectation(description: "executed")
    Executor.default.execute(from: nil) { _ in
      expectation.fulfill()
      assert(qos: .default)
    }
    self.waitForExpectations(timeout: 0.1)
  }

  func testUtility() {
    let expectation = self.expectation(description: "executed")
    Executor.utility.execute(from: nil) { _ in
      expectation.fulfill()
      assert(qos: .utility)
    }
    self.waitForExpectations(timeout: 0.1)
  }

//  func testBackground() {
//    let expectation = self.expectation(description: "executed")
//    Executor.background.execute {
//      expectation.fulfill()
//      assert(qos: .background)
//    }
//    self.waitForExpectations(timeout: 0.1)
//  }

  func testImmediate() {
    let expectation = self.expectation(description: "executed")
    Executor.immediate.execute(from: nil) { _ in
      expectation.fulfill()
      assert(on: .main)
    }
    self.waitForExpectations(timeout: 0.1)
  }

  func testCustomQueue() {
    let queue = DispatchQueue(label: "test")
    let expectation = self.expectation(description: "executed")
    Executor.queue(queue).execute(from: nil) { _ in
      expectation.fulfill()
      assert(on: queue)
    }
    self.waitForExpectations(timeout: 0.1)
  }

  func testCustomQoS() {
    let qos = pickQoS()
    let expectation = self.expectation(description: "executed")
    Executor.queue(qos).execute(from: nil) { _ in
      expectation.fulfill()
      assert(qos: qos)
    }
    self.waitForExpectations(timeout: 0.1)
  }

  func testCustomHandler() {
    func execute(block: @escaping () -> Void) {
      block()
    }

    let expectation = self.expectation(description: "executed")
    Executor(handler: execute).execute(from: nil) { _ in
      expectation.fulfill()
      assert(on: .main)
    }
    self.waitForExpectations(timeout: 0.1)
  }
}
