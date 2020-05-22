//
//  Copyright (c) 2018-2019 Anton Mironov
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

#if os(macOS)
import XCTest
import Dispatch
import AppKit
@testable import AsyncNinjaReactiveUI

class macOSTests: appleOSTests {
  static let allTests = [
    ("testNSView", testNSView),
    ("testNSTextField", testNSTextField),
    ("testNSStepper", testNSStepper)
  ]

  func testNSView() {
    let object = NSView()
    testEventStream(object.rp.alphaValue,
                    object: object,
                    keyPathOrGetSet: .left("alphaValue"),
                    values: Fixtures.cgFloats)
//    testEventStream(object.rp.isHidden,
//                    object: object,
//                    keyPathOrGetSet: .left("hidden"),
//                    values: Fixtures.bools)
    testEventStream(object.rp.isOpaque,
                    object: object,
                    keyPathOrGetSet: .left("opaque"),
                    values: Fixtures.bools)
  }

  func testNSTextField() {
    let object = NSTextField()
    testEventStream(object.rp.isEnabled,
                    object: object,
                    keyPathOrGetSet: .left("enabled"),
                    values: Fixtures.bools)
//    testEventStream(object.rp.attributedStringValue,
//                    object: object,
//                    keyPathOrGetSet: .left("attributedStringValue"),
//                    values: Fixtures.attributedStrings)
//    testEventStream(object.rp.stringValue,
//                    object: object,
//                    keyPathOrGetSet: .left("stringValue"),
//                    values: Fixtures.strings)
//    testEventStream(object.rp.integerValue,
//                    object: object,
//                    keyPathOrGetSet: .left("integerValue"),
//                    values: [1, 2, 3, 4])
//    testEventStream(object.rp.floatValue,
//                    object: object,
//                    keyPathOrGetSet: .left("floatValue"),
//                    values: [1, 2, 3, 4])
//    testEventStream(object.rp.doubleValue,
//                    object: object,
//                    keyPathOrGetSet: .left("doubleValue"),
//                    values: [1, 2, 3, 4])
  }

  func testNSStepper() {
    let object = NSStepper()
    testEventStream(object.rp.isEnabled,
                    object: object,
                    keyPathOrGetSet: .left("enabled"),
                    values: Fixtures.bools)
//    testEventSource(object.rp.stringValue,
//                    object: object,
//                    keyPathOrSet: .left("stringValue"),
//                    values: Fixtures.strings)
//    testEventSource(object.rp.integerValue,
//                    object: object,
//                    keyPathOrSet: .left("integerValue"),
//                    values: [1, 2, 3, 4])
//    testEventStream(object.rp.floatValue,
//                    object: object,
//                    keyPathOrGetSet: .left("floatValue"),
//                    values: [1, 2, 3, 4])
//    testEventStream(object.rp.doubleValue,
//                    object: object,
//                    keyPathOrGetSet: .left("doubleValue"),
//                    values: [1, 2, 3, 4])
  }
}

#endif
