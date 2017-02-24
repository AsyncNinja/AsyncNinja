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

#if os(iOS) || os(tvOS)
  import XCTest
  import Dispatch
  import UIKit
  @testable import AsyncNinja

  class iOSTests: XCTestCase {
    static let allTests = [
      ("testUIViewAlpha", testUIViewAlpha),
      ("testUIViewIsHidden", testUIViewIsHidden),
      ("testUIViewIsOpaque", testUIViewIsOpaque),
      ("testUIViewIsUserInteractionEnabled", testUIViewIsUserInteractionEnabled),
      ("testUIControlIsEnabled", testUIControlIsEnabled),
      ("testUIControlIsSelected", testUIControlIsSelected),
      ("testUIViewControllerTitle", testUIViewControllerTitle),
      ]

    let cgFloatFixture: [CGFloat] = [0.0, 0.0, 0.3, 0.5, 0.5, 1.0, 1.0]
    let boolFixture: [Bool] = [true, true, false, false, true]
    let stringsAndNilsFixture: [String?] = ["1", nil, "1", "1", "2", "2", nil, nil, "3", "1", "4"]

    func testUIViewAlpha() {
      let object = UIView()
      self.testUpdatableProperty(updatable: object.rp.alpha,
                                 object: object,
                                 keyPath: "alpha",
                                 values: cgFloatFixture)
    }

    func testUIViewIsHidden() {
      let object = UIView()
      self.testUpdatableProperty(updatable: object.rp.isHidden,
                                 object: object,
                                 keyPath: "hidden",
                                 values: boolFixture)
    }

    func testUIViewIsOpaque() {
      let object = UIView()
      self.testUpdatableProperty(updatable: object.rp.isOpaque,
                                 object: object,
                                 keyPath: "opaque",
                                 values: boolFixture)
    }

    func testUIViewIsUserInteractionEnabled() {
      let object = UIView()
      self.testUpdatableProperty(updatable: object.rp.isUserInteractionEnabled,
                                 object: object,
                                 keyPath: "userInteractionEnabled",
                                 values: boolFixture)
    }

    func testUIControlIsEnabled() {
      let object = UIControl()
      self.testUpdatableProperty(updatable: object.rp.isEnabled,
                                 object: object,
                                 keyPath: "enabled",
                                 values: boolFixture)
    }

    func testUIControlIsSelected() {
      let object = UIControl()
      self.testUpdatableProperty(updatable: object.rp.isSelected,
                                 object: object,
                                 keyPath: "selected",
                                 values: boolFixture)
    }

    func testUIViewControllerTitle() {
      let object = UIViewController()
      self.testUpdatableProperty(updatable: object.rp.title,
                                 object: object,
                                 keyPath: "title",
                                 values: stringsAndNilsFixture)
    }

    private func testUpdatableProperty<T: Equatable, Object: NSObject>(
      updatable: UpdatableProperty<T>,
      object: Object,
      keyPath: String,
      values: [T],
      file: StaticString = #file,
      line: UInt = #line) {
      let settingExpectation = self.expectation(description: "setting test finished")

      let runLoop = RunLoop.current

      DispatchQueue.global().async {
        for value in values {
          updatable.update(value)
          usleep(50_000)
          DispatchQueue.main.sync {
            XCTAssertEqual(object.value(forKeyPath: keyPath) as? T, value)
          }
        }

        settingExpectation.fulfill()
      }

      runLoop.run(until: Date().addingTimeInterval(1.0))
      self.waitForExpectations(timeout: 0.0)

      self.testUpdating(updating: updatable, object: object, keyPath: keyPath, values: values, file: file, line: line)
    }

    private func testUpdating<T: Equatable, Object: NSObject>(
      updating: Updating<T>,
      object: Object,
      keyPath: String,
      values: [T],
      file: StaticString = #file,
      line: UInt = #line
      ) {
      let gettingExpectation = self.expectation(description: "getting test finished")

      let runLoop = RunLoop.current

      DispatchQueue.global().async {
        var updatingIterator = updating.makeIterator()
        let _ = updatingIterator.next() // skip an initial value
        for value in values {
          DispatchQueue.main.sync {
            object.setValue(value, forKeyPath: keyPath)
          }

          usleep(50_000)

          XCTAssertEqual(updatingIterator.next(), value)
        }

        gettingExpectation.fulfill()
      }

      runLoop.run(until: Date().addingTimeInterval(1.0))
      self.waitForExpectations(timeout: 0.0)
    }

    private func testUpdatableProperty<T: AsyncNinjaOptionalAdaptor, Object: NSObject>(
      updatable: UpdatableProperty<T>,
      object: Object,
      keyPath: String,
      values: [T],
      file: StaticString = #file,
      line: UInt = #line) where T.AsyncNinjaWrapped: Equatable {
      let settingExpectation = self.expectation(description: "setting test finished")

      DispatchQueue.global().async {
        for value in values {
          updatable.update(value)
          usleep(50_000)
          DispatchQueue.main.sync {
            let valueWeGot = object.value(forKeyPath: keyPath) as? T
            XCTAssertEqual(valueWeGot?.asyncNinjaOptionalValue, value.asyncNinjaOptionalValue)
          }
        }

        settingExpectation.fulfill()
      }

      self.waitForExpectations(timeout: 1.0)

      self.testUpdating(updating: updatable, object: object, keyPath: keyPath, values: values, file: file, line: line)
    }

    private func testUpdating<T: AsyncNinjaOptionalAdaptor, Object: NSObject>(
      updating: Updating<T>,
      object: Object,
      keyPath: String,
      values: [T],
      file: StaticString = #file,
      line: UInt = #line)
      where T.AsyncNinjaWrapped: Equatable {
      let gettingExpectation = self.expectation(description: "getting test finished")
      DispatchQueue.global().async {
        var updatingIterator = updating.makeIterator()
        let _ = updatingIterator.next() // skip an initial value
        for value in values {
          DispatchQueue.main.sync {
            object.setValue(value, forKeyPath: keyPath)
          }
          usleep(50_000)
          XCTAssertEqual(updatingIterator.next()?.asyncNinjaOptionalValue, value.asyncNinjaOptionalValue)
        }

        gettingExpectation.fulfill()
      }

      self.waitForExpectations(timeout: 1.0)
    }
}
  
#endif
