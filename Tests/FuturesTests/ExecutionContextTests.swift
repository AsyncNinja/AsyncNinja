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
import Foundation
@testable import FunctionalConcurrency

class ExecutionContextTests : XCTestCase {
  func testFailure() {
    class ObjectToDeallocate : ExecutionContext {
      let internalQueue: DispatchQueue = DispatchQueue(label: "internal queue", attributes: [])
      let releasePool = ReleasePool()
      var executor: Executor { return .queue(self.internalQueue) }
    }

    var object : ObjectToDeallocate? = ObjectToDeallocate()

    let halfOfFutureValue = future(value: "Hello")
      .map(context: object) { (value, object) -> String in
        if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
          dispatchPrecondition(condition: .onQueue(object.internalQueue))
        }
        return "\(value) to"
    }

    XCTAssertEqual(halfOfFutureValue.wait().successValue!, "Hello to")
    object = nil
    let fullFutureValue = halfOfFutureValue.map(context: object) { (value, object) -> String in
      if #available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *) {
        dispatchPrecondition(condition: .onQueue(object.internalQueue))
      }
      return "\(value) dead"
    }
    
    XCTAssertEqual(fullFutureValue.wait().failureValue as! ConcurrencyError, ConcurrencyError.ownedDeallocated)
  }
}
