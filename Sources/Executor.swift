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

import Foundation

public enum Executor {
  case queue(DispatchQueue)
  case custom(((Void) -> Void) -> Void)

  public static var main: Executor { return .queue(DispatchQueue.main) }
  public static var userInteractive: Executor { return .queue(DispatchQueue.global(qos: .userInteractive)) }
  public static var userInitiated: Executor { return .queue(DispatchQueue.global(qos: .userInitiated)) }
  public static var `default`: Executor { return .queue(DispatchQueue.global(qos: .`default`)) }
  public static var utility: Executor { return .queue(DispatchQueue.global(qos: .utility)) }
  public static var background: Executor { return .queue(DispatchQueue.global(qos: .background)) }
  static var immediate: Executor { return .custom({ $0() }) }

  public func execute(_ block: (Void) -> Void) {
    switch self {
    case .queue(let queue):
      queue.async(execute: block)
    case .custom(let customExecutor):
      customExecutor(block)
    }
  }
}
