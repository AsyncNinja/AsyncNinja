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

final class ConstantChannel<S: Sequence, U> : Channel<S.Iterator.Element, U> {
  private let _periodicValues: S
  private let _finalValue: Fallible<U>

  override public var finalValue: Fallible<U>? { return _finalValue }

  init(periodicValues: S, finalValue: Fallible<U>) {
    _periodicValues = periodicValues
    _finalValue = finalValue
  }
  
  override func makeHandler(executor: Executor,
                            block: @escaping (Value) -> Void) -> Handler? {
    executor.execute {
      for periodicValue in self._periodicValues {
        block(.periodic(periodicValue))
      }
      
      block(.final(self._finalValue))
    }
    return nil
  }
  
}

public func channel<S: Sequence, U>(periodicValues: S, finalValue: Fallible<U>) -> Channel<S.Iterator.Element, U> {
  return ConstantChannel(periodicValues: periodicValues, finalValue: finalValue)
}
