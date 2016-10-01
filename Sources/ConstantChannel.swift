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

final class ConstantChannel<S: Collection, U> : Channel<S.Iterator.Element, U>, BufferingPeriodic
where S.IndexDistance == Int {
  private let _periodics: S
  private let _finalValue: Fallible<U>
  public var bufferSize: Int { return _periodics.count }

  override public var finalValue: Fallible<U>? { return _finalValue }

  init(periodics: S, finalValue: Fallible<U>) {
    _periodics = periodics
    _finalValue = finalValue
  }
  
  override func makeHandler(executor: Executor,
                            block: @escaping (Value) -> Void) -> Handler? {
    executor.execute {
      for periodic in self._periodics {
        block(.periodic(periodic))
      }
      
      block(.final(self._finalValue))
    }
    return nil
  }
  
}

public func channel<S: Collection, U>(periodics: S, success: U) -> Channel<S.Iterator.Element, U>
  where S.IndexDistance == Int {
    return ConstantChannel(periodics: periodics, finalValue: Fallible(success: success))
}

public func channel<S: Collection, U>(periodics: S, failure: Swift.Error) -> Channel<S.Iterator.Element, U>
  where S.IndexDistance == Int {
    return ConstantChannel(periodics: periodics, finalValue: Fallible(failure: failure))
}
