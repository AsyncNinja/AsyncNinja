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

import Foundation

public protocol ObjCExecutionContext: ExecutionContext where Self: NSObject {
}

// MARK: - retainer
/// **Internal use only** An object that calls specified block on deinit
private class DeinitNotifier {
  let _block: () -> Void

  init(block: @escaping () -> Void) {
    _block = block
  }

  deinit { _block() }
}

// **internal use only**
private struct Statics {
  static var increment: OSAtomic_int64_aligned64_t = 0
  static func withUniqueKey(_ block: (Int64) -> Void) {
    let unique = OSAtomicIncrement64Barrier(&increment)
    block(unique)
  }
}

public extension ObjCExecutionContext {
  func releaseOnDeinit(_ object: AnyObject) {
    Statics.withUniqueKey {
      "asyncNinjaKey_\($0)".withCString {
        objc_setAssociatedObject(self, $0, object,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
      }
    }
  }

  func notifyDeinit(_ block: @escaping () -> Void) {
    releaseOnDeinit(DeinitNotifier(block: block))
  }
}

#endif
