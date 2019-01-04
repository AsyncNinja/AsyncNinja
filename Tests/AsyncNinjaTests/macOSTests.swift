//
//  macOSTests.swift
//  AsyncNinjaTests
//
//  Created by Anton Mironov on 1/4/19.
//

#if os(macOS)
import XCTest
import Dispatch
import AppKit
@testable import AsyncNinja

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
    testEventStream(object.rp.isHidden,
                    object: object,
                    keyPathOrGetSet: .left("hidden"),
                    values: Fixtures.bools)
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
    testEventStream(object.rp.stringValue,
                    object: object,
                    keyPathOrGetSet: .left("stringValue"),
                    values: Fixtures.strings)
    testEventStream(object.rp.integerValue,
                    object: object,
                    keyPathOrGetSet: .left("integerValue"),
                    values: [1, 2, 3, 4])
    testEventStream(object.rp.floatValue,
                    object: object,
                    keyPathOrGetSet: .left("floatValue"),
                    values: [1, 2, 3, 4])
    testEventStream(object.rp.doubleValue,
                    object: object,
                    keyPathOrGetSet: .left("doubleValue"),
                    values: [1, 2, 3, 4])
  }

  func testNSStepper() {
    let object = NSStepper()
    testEventStream(object.rp.isEnabled,
                    object: object,
                    keyPathOrGetSet: .left("enabled"),
                    values: Fixtures.bools)
    testEventStream(object.rp.stringValue,
                    object: object,
                    keyPathOrGetSet: .left("stringValue"),
                    values: Fixtures.strings)
    testEventStream(object.rp.integerValue,
                    object: object,
                    keyPathOrGetSet: .left("integerValue"),
                    values: [1, 2, 3, 4])
    testEventStream(object.rp.floatValue,
                    object: object,
                    keyPathOrGetSet: .left("floatValue"),
                    values: [1, 2, 3, 4])
    testEventStream(object.rp.doubleValue,
                    object: object,
                    keyPathOrGetSet: .left("doubleValue"),
                    values: [1, 2, 3, 4])
  }
}

#endif
