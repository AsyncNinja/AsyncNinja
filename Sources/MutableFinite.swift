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

/// A protocol for objects that can be manually finish with value
public protocol MutableFinite: Finite, Cancellable {
  associatedtype ImmutableFinite: Finite

  /// Required initializer
  init()

  /// Completes `MutableFinite` with value and returns true.
  /// Returns false if promise was completed before.
  ///
  /// - Parameter final: value to compete `MutableFinite` with
  /// - Returns: true if this call completed future
  @discardableResult
  func tryComplete(with final: Fallible<FinalValue>) -> Bool

  /// Shorthand to tryComplete that does not return value
  func complete(with finite: ImmutableFinite)

  /// **internal use only**
  func insertToReleasePool(_ releasable: Releasable)
}

public extension MutableFinite {
  /// Completes promise when specified future completes.
  /// `self` will retain specified future until it`s completion
  func complete(with future: Future<FinalValue>) {
    let handler = future.makeFinalHandler(executor: .immediate) { [weak self] in
      self?.complete(with: $0)
    }
    if let handler = handler {
      self.insertToReleasePool(handler)
    }
  }

  /// Shorthand to tryComplete(with:) that does not return value
  func complete(with final: Fallible<FinalValue>) {
    self.tryComplete(with: final)
  }

  /// Tries to complete self with success vlue
  @discardableResult
  func trySucceed(with success: FinalValue) -> Bool {
    return self.tryComplete(with: Fallible(success: success))
  }

  /// Shorthand to trySucceed(with:) that does not return value
  func succeed(with success: FinalValue) {
    self.complete(with: Fallible(success: success))
  }

  /// Tries to complete self with failure vlue
  @discardableResult
  public func tryFail(with failure: Swift.Error) -> Bool {
    return self.tryComplete(with: Fallible(failure: failure))
  }

  /// Shorthand to tryFail(with:) that does not return value
  public func fail(with failure: Swift.Error) {
    self.complete(with: Fallible(failure: failure))
  }

  /// Completes with cancellation (AsyncNinjaError.cancelled)
  public func cancel() {
    self.fail(with: AsyncNinjaError.cancelled)
  }

  /// Completes with error of deallocated context (AsyncNinjaError.contextDeallocated)
  func cancelBecauseOfDeallocatedContext() {
    self.fail(with: AsyncNinjaError.contextDeallocated)
  }
}
