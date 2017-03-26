//
//  Copyright (c) 2017 Anton Mironov
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

// MARK: - DispatchQueue

extension DispatchQueue: ExecutorImpl {
  var asyncNinja_representedDispatchQueue: DispatchQueue? { return self }
  var asyncNinja_canImmediatelyExecuteOnPrimaryExecutor: Bool { return false }

  func asyncNinja_execute(_ block: @escaping (Void) -> Void) {
    self.async(execute: block)
  }

  func asyncNinja_execute(after timeout: Double, _ block: @escaping (Void) -> Void) {
    let wallDeadline = DispatchWallTime.now().adding(seconds: timeout)
    self.asyncAfter(wallDeadline: wallDeadline, execute: block)
  }

  func asyncNinja_canImmediatelyExecute(from impl: ExecutorImpl) -> Bool {
    return impl === self
  }
}
