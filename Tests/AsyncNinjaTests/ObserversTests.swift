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

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  class ObserversTests: XCTestCase {

    static let allTests = [
      ("testObserver", testObserver),
      ("testObserverMutation", testObserverMutation),
      ("testObserverBinding", testObserverBinding),
      ("testReceiveNotifications", testReceiveNotifications),
      ("testPostNotifications", testPostNotifications)
      ]

    func testObserver() {
      class MyObject: NSObject, ObjCInjectedRetainer {
        @objc dynamic var myValue: Int = 0
      }

      let myObject = MyObject()
      let updatingValues: Channel<Int?, Void> = myObject
        .updatable(forKeyPath: #keyPath(MyObject.myValue), executor: .main, from: .main)
      var detectedChanges = [Int]()
      updatingValues.onUpdate(executor: .immediate) {
        if let value = $0 {
          detectedChanges.append(value)
        }
      }

      let range = 1..<5
      for index in range {
        myObject.myValue = index
      }

      XCTAssertEqual(detectedChanges, [0, 1, 2, 3, 4])
    }

    func testObserverMutation() {
      class MyObject: NSObject, ObjCInjectedRetainer {
        @objc dynamic var myValue: Int = 0
      }

      let myObject = MyObject()
      let updatableProperty: ProducerProxy<Int?, Void> = myObject
        .updatable(forKeyPath: #keyPath(MyObject.myValue), executor: .main, from: .main)
      var detectedChanges = [Int]()
      updatableProperty.onUpdate(executor: .main) {
        if let value = $0 {
          detectedChanges.append(value)
        }
      }

      let range = 1..<5
      for index in range {
        updatableProperty.update(index, from: .main)
      }

      let expectation = self.expectation(description: "done")
      DispatchQueue.global().asyncAfter(deadline: DispatchTime.now() + .seconds(1)) {
        XCTAssertEqual(detectedChanges, [0, 1, 2, 3, 4])
        expectation.fulfill()
      }

      self.waitForExpectations(timeout: 2.0)
    }

    func testObserverBinding() {
      class MyObject: NSObject, ObjCInjectedRetainer {
        @objc dynamic var myValue: Int = 0
      }

      let myObject = MyObject()

      var updatableProperty: ProducerProxy<Int?, Void>? = myObject.updatable(
        forKeyPath: #keyPath(MyObject.myValue),
        executor: .main,
        from: .main)
      var detectedChanges = [Int]()
      updatableProperty!.onUpdate(executor: .main) {
        if let value = $0 {
          detectedChanges.append(value)
        }
      }

      let producer = Producer<Int?, String>()
      producer.bind(updatableProperty!)
      updatableProperty = nil

      let range = 1..<5
      for index in range {
        producer.update(index)
      }

      producer.succeed("Done")

      let expectation = self.expectation(description: "done")
      DispatchQueue.global().asyncAfter(deadline: DispatchTime.now().adding(seconds: 1.0)) {
        XCTAssertEqual(detectedChanges, [0, 1, 2, 3, 4])
        expectation.fulfill()
      }

      self.waitForExpectations(timeout: 2.0)
    }

    func testReceiveNotifications() {
      multiTest {
        let notificationCenter = NotificationCenter()
        class MyObject: NSObject {
        }

        let myObject = MyObject()
        let name = Notification.Name("my-super-notification")
        var detectedValues = [Int]()
        notificationCenter.updatable(object: myObject, name: name)
          .onUpdate {
            XCTAssert(myObject === $0.object as! NSObject)
            XCTAssertEqual(name, $0.name)
            detectedValues.append($0.userInfo!["myValue"] as! Int)
        }

        let values = [1, 2, 3, 4, 5]
        for value in values {
          notificationCenter.post(name: name, object: myObject, userInfo: ["myValue": value])
          mysleep(0.01)
        }

        mysleep(0.1)
        XCTAssertEqual(detectedValues, values)
      }
    }

    func testPostNotifications() {
      multiTest {
        let notificationCenter = NotificationCenter()
        class MyObject: NSObject {
        }

        let myObject = MyObject()
        let name = Notification.Name("my-super-notification")
        var detectedValues = [Int]()
        let token = notificationCenter.addObserver(forName: name, object: myObject, queue: nil) {
          XCTAssert(myObject === $0.object as! NSObject)
          XCTAssertEqual(name, $0.name)
          detectedValues.append($0.userInfo!["myValue"] as! Int)
        }

        let updatable = notificationCenter.updatable(object: myObject, name: name)

        let values = [1, 2, 3, 4, 5]
        for value in values {
          let notification = Notification(name: name, object: myObject, userInfo: ["myValue": value])
          updatable.update(notification)
          mysleep(0.01)
        }

        mysleep(0.1)
        notificationCenter.removeObserver(token)
        XCTAssertEqual(detectedValues, values)
      }
    }
  }
#endif
