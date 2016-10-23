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

class PipeTests : XCTestCase {
  static let allTests = [
    ("testSimple", testSimple),
    ]
  
  func testSimple() {
    let queueA = DispatchQueue(label: "queueA")
    let queueB = DispatchQueue(label: "queueB")
    
    self.measure {
      let pipe: AsyncNinja.Pipe<Int, String> = Pipe()
      let pipeInput = PipeInput(pipe: pipe)
      queueA.async {
        pipeInput.push(periodic: 1)
        pipeInput.push(periodic: 2)
        pipeInput.push(periodic: 3)
        pipeInput.push(periodic: 4)
        pipeInput.push(final: "bye")
      }
      
      let (ints, final) = future(executor: .queue(queueB)) { () -> ([Int], String) in
        var ints = [Int]()
        while true {
          switch pipe.pop() {
          case let .periodic(periodic):
            ints.append(periodic)
          case let .final(final):
            return (ints, final)
          }
        }
        }
        .wait().success!
      
      XCTAssertEqual(ints, [1, 2, 3, 4])
      XCTAssertEqual(final, "bye")
    }
  }
}
