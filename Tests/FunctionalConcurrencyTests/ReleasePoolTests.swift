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

class ReleasePoolTests : XCTestCase {
  func testSequential() {
    let releasePool = ReleasePool()
    var boxedOne: Box<Int>? = Box(1)
    var boxedTwo: Box<Int>? = Box(2)

    weak var weakBoxedOne = boxedOne
    weak var weakBoxedTwo = boxedTwo

    releasePool.insert(boxedOne)
    releasePool.insert(boxedTwo)

    boxedOne = nil
    boxedTwo = nil

    XCTAssertEqual(weakBoxedOne?.value, 1)
    XCTAssertEqual(weakBoxedTwo?.value, 2)

    releasePool.drain()

    XCTAssertNil(weakBoxedOne)
    XCTAssertNil(weakBoxedTwo)
  }

  func testConcurrent() {
    let qosClasses: [DispatchQoS.QoSClass] = [.background, .utility, .default, .userInitiated, .userInteractive]
    let queues = qosClasses.map(DispatchQueue.global(qos:))
    let releasePool = ReleasePool()

    var boxes = (0..<10000).map(Box.init)
    let weakBoxes: [WeakBox] = boxes.map(WeakBox.init)

    let group = DispatchGroup()
    boxes.enumerated()
      .map { ($1, queues[$0 % queues.count]) }
      .forEach { (box, queue) in
        queue.async(group: group) { releasePool.insert(box) }
    }
    boxes.removeAll(keepingCapacity: false)
    group.wait()

    for (index, weakBox) in weakBoxes.enumerated() {
      XCTAssertEqual(weakBox.value?.value, index)
    }

    releasePool.drain()

    for weakBox in weakBoxes {
      XCTAssertNil(weakBox.value)
    }
  }
}

fileprivate class Box<T> {
  let value: T
  init(_ value: T) {
    self.value = value
  }
}

fileprivate class WeakBox<T: AnyObject> {
  weak var value: T?
  init(_ value: T) {
    self.value = value
  }
}
