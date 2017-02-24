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

import Dispatch

extension Dictionary {
  mutating func value(forKey key: Key,
                      orMake makeValue: (Key) throws -> Value
    ) rethrows -> Value {
    if let existingValue = self[key] {
      return existingValue
    } else {
      let newValue = try makeValue(key)
      self[key] = newValue
      return newValue
    }
  }
}

func nop() {
  // no operation
}

func assertAbstract(file: StaticString = #file, line: UInt = #line) -> Never {
  fatalError("This methods is abstract. May not reach here", file: file, line: line)
}

// MARK: - Either

/// Simple implementation of either monad
public enum Either<Left, Right> {

  /// left case
  case left(Left)

  /// right case
  case right(Right)

  /// returns left value if there is one
  public var left: Left? {
    if case let .left(value) = self { return value }
    else { return nil }
  }

  /// returns right value if there is one
  public var right: Right? {
    if case let .right(value) = self { return value }
    else { return nil }
  }
}

// MARK: - Description
extension Either: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of this instance.
  public var description: String {
    return description(withBody: "")
  }

  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    return description(withBody: "<\(Left.self), \(Right.self)>")
  }

  /// **internal use only**
  private func description(withBody body: String) -> String {
    switch self {
    case .left(let value):
      return "left\(body)(\(value))"
    case .right(let value):
      return "right\(body)(\(value))"
    }
  }
}

// MARK: - Equatable
extension Either where Left: Equatable, Right: Equatable {

  /// implementation of an "equals" operatior
  public static func ==(lhs: Either, rhs: Either) -> Bool {
    switch (lhs, rhs) {
    case let (.left(valueA), .left(valueB)):
      return valueA == valueB
    case let (.right(valueA), .right(valueB)):
      return valueA == valueB
    default:
      return false
    }
  }
}

extension DispatchTime {
  func adding(seconds: Double) -> DispatchTime {
    #if arch(x86_64) || arch(arm64)
      return self + .nanoseconds(Int(seconds * 1_000_000_000.0))
    #else
      return self + .milliseconds(Int(seconds * 1_000.0))
    #endif
  }
}

extension DispatchWallTime {
  func adding(seconds: Double) -> DispatchWallTime {
    #if arch(x86_64) || arch(arm64)
      return self + .nanoseconds(Int(seconds * 1_000_000_000.0))
    #else
      return self + .milliseconds(Int(seconds * 1_000.0))
    #endif
  }
}
