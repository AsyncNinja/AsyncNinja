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

/// ProducerProxy acts like a producer but is actually a proxy for some operation, e.g. setting and oberving property
public class ProducerProxy<Update, Success>: BaseProducer<Update, Success> {
  typealias UpdateHandler = (
    _ producer: ProducerProxy<Update, Success>,
    _ event: ChannelEvent<Update, Success>,
    _ originalExecutor: Executor?
    ) -> Void
  private let _updateHandler: UpdateHandler
  private let _updateExecutor: Executor

  /// designated initializer
  init(updateExecutor: Executor,
       bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize,
       updateHandler: @escaping UpdateHandler) {
    _updateHandler = updateHandler
    _updateExecutor = updateExecutor
    super.init(bufferSize: bufferSize)
  }

  func tryUpdateWithoutHandling(_ update: Update, from originalExecutor: Executor?) -> Bool {
    return super.tryUpdate(update, from: originalExecutor)
  }

  func tryCompleteWithoutHandling(
    with completion: Fallible<Success>,
    from originalExecutor: Executor?) -> Bool {
    return super.tryComplete(completion, from: originalExecutor)
  }

  /// Calls update handler instead of sending specified Update to the Producer
  override public func tryUpdate(_ update: Update, from originalExecutor: Executor?) -> Bool {
    guard case .none = self.completion else { return false }
    _updateExecutor.execute(
      from: originalExecutor
    ) { (originalExecutor) in
      self._updateHandler(self, .update(update), originalExecutor)
    }

    return true
  }

  /// Calls update handler instead of sending specified Complete to the Producer
  override public func tryComplete(_ completion: Fallible<Success>, from originalExecutor: Executor? = nil) -> Bool {
    guard case .none = self.completion else { return false }
    _updateExecutor.execute(
      from: originalExecutor
    ) { (originalExecutor) in
      self._updateHandler(self, .completion(completion), originalExecutor)
    }
    return true
  }
}
