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
@testable import AsyncNinja
#if os(Linux)
  import Glibc
#endif

class CachableValueTests : XCTestCase {
  
  static let allTests = [
    ("testA", testA),
    ]
  
  func testA() {
    
    class CachedValueHolder : ExecutionContext, ReleasePoolOwner {
      private(set) var cachableValue: SimpleCachableValue<Int, CachedValueHolder>!
      let executor = Executor.queue(DispatchQueue(label: "cached-value-holder-queue"))
      let releasePool = ReleasePool()
      
      init() {
        self.cachableValue = SimpleCachableValue(context: self, missHandler: { $0.provideValue() })
      }
      
      private func provideValue() -> Future<Int> {
        return future(after: 1.0) { 3 }
      }
      
    }
    
    let holder = CachedValueHolder()
    XCTAssertEqual(holder.cachableValue.value().wait().success, 3)
  }
}
