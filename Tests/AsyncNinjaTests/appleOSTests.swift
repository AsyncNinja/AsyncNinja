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

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

import XCTest
import Dispatch
@testable import AsyncNinja

class appleOSTests: XCTestCase {
}

// MARK: - T: Equatable
extension appleOSTests {
  func testEventStream<T: EventDestination&EventSource, Object: NSObject>(
    _ stream: T,
    object: Object,
    keyPathOrGetSet: Either<String, (getter: (Object) -> T.Update?, setter: (Object, T.Update?) -> Void)>,
    values: [T.Update],
    file: StaticString = #file,
    line: UInt = #line
    ) where T.Update: Equatable {
    testEventDestination(stream, object: object, keyPathOrGet: keyPathOrGetSet.mapRight { $0.getter },
                         values: values, file: file, line: line)
    testEventSource(stream, object: object, keyPathOrSet: keyPathOrGetSet.mapRight { $0.setter },
                    values: values, file: file, line: line)
  }

  func testEventDestination<T: EventDestination, Object: NSObject>(
    _ eventDestination: T,
    object: Object,
    keyPathOrGet: Either<String, (Object) -> T.Update?>,
    values: [T.Update],
    file: StaticString = #file,
    line: UInt = #line
    ) where T.Update: Equatable {
    for value in values {
      eventDestination.update(value, from: .main)
      let objectValue: T.Update? = eval {
        switch keyPathOrGet {
        case let .left(keyPath):
          return object.value(forKeyPath: keyPath) as? T.Update
        case let .right(getter):
          return getter(object)
        }
      }
      XCTAssertEqual(objectValue, value, file: file, line: line)
    }
  }

  func testEventSource<T: EventSource, Object: NSObject>(
    _ eventSource: T,
    object: Object,
    keyPathOrSet: Either<String, (Object, T.Update?) -> Void>,
    values: [T.Update],
    file: StaticString = #file,
    line: UInt = #line
    ) where T.Update: Equatable {
    var updatingIterator = eventSource.makeIterator()
    _ = updatingIterator.next() // skip an initial value
    for value in values {
      switch keyPathOrSet {
      case let .left(keyPath):
        object.setValue(value, forKeyPath: keyPath)
      case let .right(setter):
        setter(object, value)
      }

      XCTAssertEqual(updatingIterator.next() as! T.Update?, value, file: file, line: line)
    }
  }

}

// MARK: - T: Optional<Equatable>
extension appleOSTests {
  func testOptionalEventStream<T: EventDestination&EventSource, Object: NSObject>(
    _ stream: T,
    object: Object,
    keyPathOrGetSet: Either<String, (getter: (Object) -> T.Update?, setter: (Object, T.Update?) -> Void)>,
    values: [T.Update],
    file: StaticString = #file,
    line: UInt = #line
    ) where T.Update: AsyncNinjaOptionalAdaptor,
    T.Update.AsyncNinjaWrapped: Equatable {
      testOptionalEventDestination(stream,
                                   object: object,
                                   keyPathOrGet: keyPathOrGetSet.mapRight { $0.getter },
                                   values: values,
                                   file: file,
                                   line: line)
      testOptionalEventSource(stream,
                              object: object,
                              keyPathOrSet: keyPathOrGetSet.mapRight { $0.setter },
                              values: values,
                              file: file,
                              line: line)
  }

  func testOptionalEventDestination<T: EventDestination, Object: NSObject>(
    _ eventDestination: T,
    object: Object,
    keyPathOrGet: Either<String, (Object) -> T.Update?>,
    values: [T.Update],
    file: StaticString = #file,
    line: UInt = #line,
    customGetter: ((Object) -> T.Update?)? = nil
    ) where T.Update: AsyncNinjaOptionalAdaptor,
    T.Update.AsyncNinjaWrapped: Equatable {
      for value in values {
        eventDestination.update(value, from: .main)
        let objectValue: T.Update? = eval {
          switch keyPathOrGet {
          case let .left(keyPath):
            return object.value(forKeyPath: keyPath) as? T.Update
          case let .right(getter):
            return getter(object)
          }
        }
        XCTAssertEqual(objectValue?.asyncNinjaOptionalValue, value.asyncNinjaOptionalValue, file: file, line: line)
      }
  }

  func testOptionalEventSource<T: EventSource, Object: NSObject>(
    _ eventSource: T,
    object: Object,
    keyPathOrSet: Either<String, (Object, T.Update?) -> Void>,
    values: [T.Update],
    file: StaticString = #file,
    line: UInt = #line
    ) where T.Update: AsyncNinjaOptionalAdaptor,
    T.Update.AsyncNinjaWrapped: Equatable {
      var updatingIterator = eventSource.makeIterator()
      _ = updatingIterator.next() // skip an initial value
      for value in values {
        switch keyPathOrSet {
        case let .left(keyPath):
          object.setValue(value.asyncNinjaOptionalValue, forKeyPath: keyPath)
        case let .right(setter):
          setter(object, value)
        }

        XCTAssertEqual((updatingIterator.next() as! T.Update?)?.asyncNinjaOptionalValue,
                       value.asyncNinjaOptionalValue, file: file, line: line)
      }
  }
}

#endif
