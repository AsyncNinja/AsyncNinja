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

public protocol MutableFinite : Finite {
  /// Completes promise with value and returns true.
  /// Returns false if promise was completed before.
  @discardableResult
  func complete(with final: FinalValue) -> Bool

  func insertToReleasePool(_ releasable: Releasable)
}

public extension MutableFinite {
  /// Completes promise when specified future completes.
  /// `self` will retain specified future until it`s completion
  @discardableResult
  final public func complete(with future: Future<FinalValue>) {
    let handler = future.makeFinalHandler(executor: .immediate) { [weak self] in
      self?.complete(with: $0)
    }
    if let handler = handler {
      self.insertToReleasePool(handler)
    }
  }
}

public extension MutableFinite where FinalValue : _Fallible {
  final public func succeed(with success: FinalValue.Success) {
    self.complete(with: FinalValue(success: success))
  }

  final public func fail(with failure: Error) {
    self.complete(with: FinalValue(failure: failure))
  }

  final public func cancel() {
    self.fail(with: ConcurrencyError.cancelled)
  }

  final func cancelBecauseOfDeallicatedContext() {
    self.fail(with: ConcurrencyError.contextDeallocated)
  }
}
