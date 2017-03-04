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

public protocol Updatable: LifetimeExtender {
  associatedtype Update

  func update(_ update: Update,
              from originalExecutor: Executor?)
}

public protocol Streamable: Updatable, Completable {
}

public extension Streamable {
  typealias Event = ChannelEvent<Update, Success>

  /// Applies specified ChannelValue to the Producer
  /// Value will not be applied for completed Producer
  ///
  /// - Parameter event: `Event` to apply.
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  public func apply(_ event: ChannelEvent<Update, Success>,
                    from originalExecutor: Executor? = nil) {
    switch event {
    case let .update(update):
      self.update(update, from: originalExecutor)
    case let .completion(completion):
      self.complete(completion, from: originalExecutor)
    }
  }
}
