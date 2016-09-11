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

public class FiniteChannel<T, U> {
  public typealias RegularValue = T
  public typealias FinalValue = U
  public typealias Value = FiniteChannelValue<RegularValue, FinalValue>
  public typealias Handler = FiniteChannelHandler<RegularValue, FinalValue>

  let releasePool = ReleasePool()

  init() { }

  public func add(handler: Handler) {
    fatalError() // abstract
  }
}

extension FiniteChannel : _Channel {
}

public enum FiniteChannelValue<T, U> {
  public typealias RegularValue = T
  public typealias FinalValue = U

  case regular(RegularValue)
  case final(FinalValue)
}

final public class FiniteChannelHandler<T, U> : _ChannelHandler {
  public typealias RegularValue = T
  public typealias FinalValue = U
  public typealias Value = FiniteChannelValue<RegularValue, FinalValue>

  let executor: Executor
  let block: (Value) -> Void

  public init(executor: Executor, block: @escaping (Value) -> Void) {
    self.executor = executor
    self.block = block
  }

  func handle(value: Value) {
    let block = self.block
    self.executor.execute { block(value) }
  }
}
