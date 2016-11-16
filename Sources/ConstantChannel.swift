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

#if false // ConstantChannel is disabled because it does not meet requirements. Let's review it after taking care pf laziness
final class ConstantChannel<S: Collection, U> : Channel<S.Iterator.Element, U>
where S.IndexDistance == Int {
  private let _periodics: [S.Iterator.Element]
  private let _finalValue: Fallible<U>
  private let _maxBufferSize: Int
  override public var bufferSize: Int { return _periodics.count }
  override public var maxBufferSize: Int { return _maxBufferSize }

  override public var finalValue: Fallible<U>? { return _finalValue }

  init(periodics: S, finalValue: Fallible<U>) {
    _periodics = Array(periodics)
    _finalValue = finalValue
    _maxBufferSize = _periodics.count
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

  override public func makeIterator() -> Iterator {
    let impl = ConstantChannelIteratorImp(periodicsIterator: _periodics.makeIterator(), finalValue: _finalValue)
    return ChannelIterator(impl: impl)
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

class ConstantChannelIteratorImp<PeriodicValue, FinalValue> : ChannelIteratorImpl<PeriodicValue, FinalValue> {
  private var _periodicsIterator: Array<PeriodicValue>.Iterator
  private let _finalValue: Fallible<FinalValue>
  override var finalValue: Fallible<FinalValue>? { return _finalValue }

  init(periodicsIterator: Array<PeriodicValue>.Iterator, finalValue: Fallible<FinalValue>) {
    _periodicsIterator = periodicsIterator
    _finalValue = finalValue
  }

  override func next() -> PeriodicValue? {
    return _periodicsIterator.next()
  }

  override func clone() -> ChannelIteratorImpl<PeriodicValue, FinalValue> {
    return ConstantChannelIteratorImp(periodicsIterator: _periodicsIterator, finalValue: _finalValue)
  }
}

#endif
