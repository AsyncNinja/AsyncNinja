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

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

import Foundation

public extension ExecutionContext where Self: NSObject {
}

extension ExecutionContext where Self: NSObject {
  public subscript<Value>(updatingKeyPath keyPath: KeyPath<Self, Value>) -> Channel<Value, Void> {
    return updating(forKeyPath: keyPath,
                    executor: executor,
                    from: executor,
                    customGetter: type(of: self).asyncNinjaCustomGetter(keyPath: keyPath))
  }

  public subscript<Value>(
    updatableKeyPath keyPath: ReferenceWritableKeyPath<Self, Value>
    ) -> BaseProducer<Value, Void> {
      return updatable(forKeyPath: keyPath,
                       executor: executor,
                       from: executor,
                       customGetter: type(of: self).asyncNinjaCustomGetter(keyPath: keyPath),
                       customSetter: type(of: self).asyncNinjaCustomSetter(keyPath: keyPath))
  }

  public static func asyncNinjaRegister<Value>(
    keyPath: KeyPath<Self, Value>,
    getter: @escaping (Self) -> Value) {

  }

  public static func asyncNinjaRegister<Value>(
    keyPath: ReferenceWritableKeyPath<Self, Value>,
    getter: @escaping (Self) -> Value,
    setter: @escaping (Self, Value) -> Void) {

  }

  static func asyncNinjaCustomGetter<Self, Value>(
    keyPath: KeyPath<Self, Value>
    ) -> ((Self) -> Value)? {
    return nil
  }

  static func asyncNinjaCustomSetter<Self, Value>(
    keyPath: ReferenceWritableKeyPath<Self, Value>
    ) -> ((Self, Value) -> Void)? {
    return nil
  }
}

public extension NSObject {
  @objc public class func asyncNinjaRegister() {
  }
}

#endif
