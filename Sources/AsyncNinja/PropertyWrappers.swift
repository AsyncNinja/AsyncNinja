//
//  Copyright (c) 2016-2020 Anton Mironov, Sergiy Vynnychenko
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

import Foundation

/// using: @WrappedProducer var variable = "String Value"
/// variable can be used as usual
/// channel can be accessed as $variable
@propertyWrapper public struct WrappedProducer<Value> {
  public var wrappedValue : Value { didSet { _producer.update(wrappedValue)  } }
  
  /// The property that can be accessed with the `$` syntax and allows access to the `Channel`
  public var projectedValue: Channel<Value, Void> { get { return _producer } }
  
  private let _producer : Producer<Value, Void>
  
  /// Initialize the storage of the Published property as well as the corresponding `Publisher`.
  public init(wrappedValue: Value) {
    self.wrappedValue = wrappedValue
    self._producer = Producer<Value,Void>(bufferSize: 1, bufferedUpdates: [wrappedValue])
  }
}
