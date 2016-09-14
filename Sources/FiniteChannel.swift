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

public class FiniteChannel<T, U> : Periodical, Finite {
  public typealias PeriodicalValue = T
  public typealias FinalValue = U
  public typealias Value = FiniteChannelValue<PeriodicalValue, FinalValue>
  public typealias Handler = FiniteChannelHandler<PeriodicalValue, FinalValue>
  public typealias PeriodicalHandler = Handler
  public typealias FinalHandler = Handler

  let releasePool = ReleasePool()

  init() { }

  final public func makeFinalHandler(executor: Executor, block: @escaping (FinalValue) -> Void) -> Handler? {
    return self.makeHandler(executor: executor) {
      if case .final(let value) = $0 { block(value) }
    }
  }

  final public func makePeriodicalHandler(executor: Executor, block: @escaping (PeriodicalValue) -> Void) -> Handler? {
    return self.makeHandler(executor: executor) {
      if case .periodical(let value) = $0 { block(value) }
    }
  }
  public func makeHandler(executor: Executor, block: @escaping (Value) -> Void) -> Handler? {
    /* abstract */
    fatalError()
  }
}

public enum FiniteChannelValue<T, U> {
  public typealias PeriodicalValue = T
  public typealias FinalValue = U

  case periodical(PeriodicalValue)
  case final(FinalValue)
}

/// **internal use only**
final public class FiniteChannelHandler<T, U> {
  public typealias PeriodicalValue = T
  public typealias FinalValue = U
  public typealias Value = FiniteChannelValue<PeriodicalValue, FinalValue>

  let executor: Executor
  let block: (Value) -> Void

  public init(executor: Executor, block: @escaping (Value) -> Void) {
    self.executor = executor
    self.block = block
  }

  func handle(_ value: Value) {
    let block = self.block
    self.executor.execute { block(value) }
  }
}
