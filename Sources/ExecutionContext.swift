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

import Dispatch

public protocol ExecutionContext : class {
  var executor: Executor { get }
  func releaseOnDeinit(_ object: AnyObject)
  func notifyDeinit(_ block: @escaping () -> Void)
}

public protocol ReleasePoolOwner {
  var releasePool: ReleasePool { get }
}

public extension ExecutionContext where Self : ReleasePoolOwner {
  func releaseOnDeinit(_ object: AnyObject) {
    self.releasePool.insert(object)
  }

  func notifyDeinit(_ block: @escaping () -> Void) {
    self.releasePool.notifyDrain(block)
  }
}

protocol ExecutionContextProxy : ExecutionContext {
    var context: ExecutionContext { get }
}

extension ExecutionContextProxy {
    public var executor: Executor { return self.context.executor }
    
    public func releaseOnDeinit(_ object: AnyObject) {
        self.releaseOnDeinit(object)
    }

    public func notifyDeinit(_ block: @escaping () -> Void) {
        self.notifyDeinit(block)
    }
}
