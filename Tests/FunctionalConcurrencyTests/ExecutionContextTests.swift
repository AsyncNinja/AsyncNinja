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

import XCTest
import Dispatch
@testable import FunctionalConcurrency

struct SimpleRequest {}
struct SimpleResponse {}

class ExecutionContextTests : XCTestCase {
  func testFailure() {
    class ObjectToDeallocate : ExecutionContext, ReleasePoolOwner {
      let internalQueue = DispatchQueue(label: "internal queue", attributes: [])
      var executor: Executor { return .queue(self.internalQueue) }
      let releasePool = ReleasePool()

      func perform(request: SimpleRequest) -> FallibleFuture<SimpleResponse> {
        return future(context: self) { try $0._perform(request: request) }
      }

      private func _perform(request: SimpleRequest) throws -> SimpleResponse {
        // do work
        return SimpleResponse()
      }
    }

    var object : ObjectToDeallocate? = ObjectToDeallocate()

    let halfOfFutureValue = future(value: "Hello")
      .map(context: object!) { (object, value) -> String in
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
          dispatchPrecondition(condition: .onQueue(object.internalQueue))
        }
        return "\(value) to"
    }

    XCTAssertEqual(halfOfFutureValue.wait().successValue!, "Hello to")
    let fullFutureValue = halfOfFutureValue
      .map(context: object!) { (object, value) -> String in
      if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
        dispatchPrecondition(condition: .onQueue(object.internalQueue))
      }
      return "\(value) dead"
    }
    object = nil
    
    XCTAssertEqual(fullFutureValue.wait().failureValue as! ConcurrencyError, ConcurrencyError.contextDeallocated)
  }
}
