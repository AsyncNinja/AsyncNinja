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

/// Producer that can be manually created
final public class Producer<Update, Success>: BaseProducer<Update, Success>, CachableCompletable {
  public typealias CompletingType = Channel<Update, Success>

  /// convenience initializer of Producer. Initializes Producer with default buffer size
  public init() {
    super.init(bufferSize: AsyncNinjaConstants.defaultChannelBufferSize)
  }

  /// designated initializer of Producer. Initializes Producer with specified buffer size
  override public init(bufferSize: Int) {
    super.init(bufferSize: bufferSize)
  }

  /// designated initializer of Producer. Initializes Producer with specified buffer size and values
  public init<S: Sequence>(bufferSize: Int, bufferedUpdates: S) where S.Iterator.Element == Update {
    super.init(bufferSize: bufferSize)
    _bufferedUpdates.push(bufferedUpdates.suffix(bufferSize))
  }

  /// designated initializer of Producer. Initializes Producer with specified buffer size and values
  public init<C: Collection>(bufferedUpdates: C) where C.Iterator.Element == Update {
    super.init(bufferSize: numericCast(bufferedUpdates.count))
    _bufferedUpdates.push(bufferedUpdates)
  }
}
