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

class EventSource_ScanTests: XCTestCase {

  static let allTests = [
    ("testScanContextual", testScanContextual),
    ("testScan", testScan),
    ("testReduceContextual", testReduceContextual),
    ("testReduce", testReduce)
    ]

  func testScanContextual() {
    multiTest {
      let actor = TestActor()
      let producer = Producer<String, Int>()
      let sema = DispatchSemaphore(value: 0)

      let channel: Channel<String, (String, Int)> = producer.scan("A",
                                                                  context: actor
      ) { (actor, accumulator, value) -> String in
        assert(actor: actor)
        return accumulator + value
      }

      channel.extractAll().onSuccess {
        XCTAssertEqual($0.updates, ["AB", "ABC", "ABCD", "ABCDE", "ABCDEF"])
        XCTAssertEqual($0.completion.success!.0, "ABCDEF")
        XCTAssertEqual($0.completion.success!.1, 7)
        sema.signal()
      }

      producer.update("B")
      producer.update("C")
      producer.update("D")
      producer.update("E")
      producer.update("F")
      producer.succeed(7)
      sema.wait()
    }
  }

  func testScan() {
    multiTest {
      let producer = Producer<String, Int>()
      let sema = DispatchSemaphore(value: 0)

      let channel: Channel<String, (String, Int)> = producer.scan("A") { (accumulator, value) -> String in
        return accumulator + value
      }

      channel.extractAll().onSuccess {
        XCTAssertEqual($0.updates, ["AB", "ABC", "ABCD", "ABCDE", "ABCDEF"])
        XCTAssertEqual($0.completion.success!.0, "ABCDEF")
        XCTAssertEqual($0.completion.success!.1, 7)
        sema.signal()
      }

      producer.update("B")
      producer.update("C")
      producer.update("D")
      producer.update("E")
      producer.update("F")
      producer.succeed(7)
      sema.wait()
    }
  }

  func testReduceContextual() {
    multiTest {
      let actor = TestActor()
      let producer = Producer<String, Int>()
      let sema = DispatchSemaphore(value: 0)

      let future = producer.reduce("A", context: actor) { (actor, accumulator, value) -> String in
        assert(actor: actor)
        return accumulator + value
      }

      future.onSuccess {
        let (concatString, successValue) = $0
        XCTAssertEqual(concatString, "ABCDEF")
        XCTAssertEqual(successValue, 7)
        sema.signal()
      }

      producer.update("B")
      producer.update("C")
      producer.update("D")
      producer.update("E")
      producer.update("F")
      producer.succeed(7)
      sema.wait()
    }
  }

  func testReduce() {
    multiTest {
      let producer = Producer<String, Int>()
      let sema = DispatchSemaphore(value: 0)

      let future: Future<(String, Int)> = producer.reduce("A") { (accumulator, value) -> String in
        return accumulator + value
      }

      future.onSuccess {
        let (concatString, successValue) = $0
        XCTAssertEqual(concatString, "ABCDEF")
        XCTAssertEqual(successValue, 7)
        sema.signal()
      }

      producer.update("B")
      producer.update("C")
      producer.update("D")
      producer.update("E")
      producer.update("F")
      producer.succeed(7)
      sema.wait()
    }
  }
}
