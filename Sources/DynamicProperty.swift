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

/// DynamicProperty acts like a property but looks like a `Producer`.
/// You can make non Objective-C dynamic properties with it.
public class DynamicProperty<T>: BaseProducer<T, Void> {
  /// Value that property contains
  /// It is safe to use this property for any `Executor` but do not expect it to be updated immediatly.
  public var value: T {
    get { return _value }
    set { self.update(newValue) }
  }
  
  private let _updateExecutor: Executor
  private var _value: T
  
  /// designated initializer
  init(initialValue: T,
       updateExecutor: Executor,
       bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize)
  {
    _updateExecutor = updateExecutor
    _value = initialValue
    super.init(bufferSize: bufferSize)
    _pushUpdateToBuffer(initialValue)
  }
  
  /// Calls update handler instead of sending specified Update to the Producer
  override public func tryUpdate(_ update: Update, from originalExecutor: Executor?) -> Bool {
    if super.tryUpdate(update, from: originalExecutor) {
      _updateExecutor.execute(from: originalExecutor) {
        [weak self] (originalExecutor) in
        self?._value = update
      }
      return true
    } else {
      return false
    }
  }
}
