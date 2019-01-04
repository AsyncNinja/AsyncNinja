//
//  Copyright (c) 2018 Anton Mironov
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

import Foundation
import Dispatch

private func loggableFileName(_ file: String) -> String {
  guard let slashIndex = file.lastIndex(of: "/") else {
    return file
  }

  let index = file.index(after: slashIndex)
  return String(file[index...])
}

private func logDebug(identifier: String, content: String) {
  print("\(AsyncNinjaConstants.debugDateFormatter.string(from: Date())) - \(identifier): \(content)")
}

private func identifier(file: String, line: UInt, function: String) -> String {
  return "\(loggableFileName(file)):\(line) - \(function)"
}

/// debugging assistance
public extension Completing {
  /// prints out completion
  func debugCompletion(identifier: String) {
    onComplete(executor: .immediate) { (completion) in
      logDebug(identifier: identifier, content: "Completed \(completion)")
    }
  }

  /// prints out completion
  func debugCompletion(file: String = #file, line: UInt = #line, function: String = #function) {
    debugCompletion(identifier: identifier(file: file, line: line, function: function))
  }
}

/// debugging assistance
public extension Updating {
  /// prints out each update
  func debugUpdates(identifier: String) {
    onUpdate(executor: .immediate) { (update) in
      logDebug(identifier: identifier, content: "Update \(update)")
    }
  }

  /// prints out each update
  func debugUpdates(file: String = #file, line: UInt = #line, function: String = #function) {
    debugUpdates(identifier: identifier(file: file, line: line, function: function))
  }
}

/// debugging assistance
public extension Future {
  /// prints out completion
  func debug(identifier: String) {
    debugCompletion(identifier: identifier)
  }

  /// prints out completion
  func debug(file: String = #file, line: UInt = #line, function: String = #function) {
    debugCompletion(file: file, line: line, function: function)
  }
}

/// debugging assistance
public extension Channel {
  /// prints out each update and completion
  func debug(identifier: String) {
    debugUpdates(identifier: identifier)
    debugCompletion(identifier: identifier)
  }

  /// prints out each update and completion
  func debug(file: String = #file, line: UInt = #line, function: String = #function) {
    debugUpdates(file: file, line: line, function: function)
    debugCompletion(file: file, line: line, function: function)
  }
}
