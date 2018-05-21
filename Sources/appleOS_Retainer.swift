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

public extension Retainer where Self: NSObject {
  public typealias CustomGetter<Value> = (Self) -> Value
  public typealias CustomSetter<Value> = (Self, Value) -> Void

  /// makes an `UpdatableProperty<T>` for specified key path.
  ///
  /// `UpdatableProperty` is a kind of `Producer` so you can:
  /// * subscribe for updates
  /// * transform using `map`, `flatMap`, `filter`, `debounce`, `distinct`, ...
  /// * update manually with `update()` method
  /// * bind `Channel` to an `UpdatableProperty` using `Channel.bind`
  ///
  /// - Parameter keyPath: to observe.
  ///
  ///   **Make sure that keyPath refers to KVO-compliant property**.
  ///   * Make sure that properties defined in swift have dynamic attribute.
  ///   * Make sure that methods `class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String>`
  ///   return correct values for read-only properties
  /// - Parameter executor: to subscribe and update value on
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  /// - Parameter observationSession: is an object that helps to control observation
  /// - Parameter channelBufferSize: size of the buffer within returned channel
  /// - Parameter customGetter: provides a custom getter to use instead of value(forKeyPath:) call
  /// - Parameter customSetter: provides a custom getter to use instead of setValue(_: forKeyPath:) call
  /// - Returns: an `UpdatableProperty<T>` bound to observe and update specified keyPath
  func objcKVOUpdatable<Value>(
    forKeyPath keyPath: AnyKeyPath,
    executor: Executor,
    from originalExecutor: Executor? = nil,
    observationSession: ObservationSession? = nil,
    channelBufferSize: Int = 1,
    customGetter: CustomGetter<Value>? = nil,
    customSetter: CustomSetter<Value>? = nil
    ) -> ProducerProxy<Value, Void> {
    guard let keyPath_ = keyPath as? ReferenceWritableKeyPath<Self, Value> else {
      fatalError("Unsupported key path provided")
    }

    let producer = ProducerProxy<Value, Void>(
      updateExecutor: executor,
      bufferSize: channelBufferSize
    ) { [weak maybeSelf = self] (_, event, _) in
      guard
        let strongSelf = maybeSelf,
        case let .update(value) = event
        else { return }
      if let customSetter = customSetter {
        customSetter(self, value)
      } else {
        strongSelf[keyPath: keyPath_] = value
      }
    }

    executor.execute(from: originalExecutor) { _ in
      let observer: KeyPathObserver<Self, Value>
      if let customGetter = customGetter {
        _ = producer.tryUpdateWithoutHandling(customGetter(self), from: executor)
        observer = KeyPathObserver(keyPath: keyPath_, object: self, options: []
        ) { [weak producer] (self_, _) in
          _ = producer?.tryUpdateWithoutHandling(customGetter(self_), from: executor)
        }
      } else {
        _ = producer.tryUpdateWithoutHandling(self[keyPath: keyPath_], from: executor)
        observer = KeyPathObserver(keyPath: keyPath_, object: self, options: []
        ) { [weak producer] (self_, _) in
          _ = producer?.tryUpdateWithoutHandling(self_[keyPath: keyPath_], from: executor)
        }
      }

      observationSession?.insert(item: observer)
      self.notifyDeinit {
        producer.cancelBecauseOfDeallocatedContext(from: nil)
        observer.isEnabled = false
      }
    }

    return producer
  }

  /// makes an `Updating<T>` for specified key path.
  ///
  /// `Updating` is a kind of `Channel` so you can:
  /// * subscribe for updates
  /// * transform using `map`, `flatMap`, `filter`, `debounce`, `distinct`, ...
  ///
  /// - Parameter keyPath: to observe.
  ///
  ///   **Make sure that keyPath refers to KVO-compliant property**.
  ///   * Make sure that properties defined in swift have dynamic attribute.
  ///   * Make sure that methods `class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String>`
  ///   return correct values for read-only properties
  /// - Parameter executor: to subscribe and update value on
  /// - Parameter originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous executions
  ///   on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  /// - Parameter observationSession: is an object that helps to control observation
  /// - Parameter channelBufferSize: size of the buffer within returned channel
  /// - Parameter customGetter: provides a custom getter to use instead of value(forKeyPath:) call
  /// - Returns: an `Updating<T>` bound to observe and update specified keyPath
  func objcKVOUpdating<Value>(
    forKeyPath keyPath: AnyKeyPath,
    executor: Executor,
    from originalExecutor: Executor? = nil,
    observationSession: ObservationSession? = nil,
    channelBufferSize: Int = 1,
    customGetter: CustomGetter<Value>? = nil
    ) -> Channel<Value, Void> {

    guard let keyPath_ = keyPath as? KeyPath<Self, Value> else {
      fatalError("Unsupported key path provided")
    }

    let producer = Producer<Value, Void>(bufferSize: channelBufferSize)
    executor.execute(from: originalExecutor) { _ in
      let observer: KeyPathObserver<Self, Value>
      if let customGetter = customGetter {
        _ = producer.update(customGetter(self), from: executor)
        observer = KeyPathObserver(keyPath: keyPath_, object: self, options: []
        ) { [weak producer] (self_, _) in
          _ = producer?.update(customGetter(self_), from: executor)
        }
      } else {
        _ = producer.update(self[keyPath: keyPath_], from: executor)
        observer = KeyPathObserver(keyPath: keyPath_, object: self, options: []
        ) { [weak producer] (self_, _) in
          _ = producer?.update(self_[keyPath: keyPath_], from: executor)
        }
      }

      observationSession?.insert(item: observer)
      self.notifyDeinit {
        producer.cancelBecauseOfDeallocatedContext(from: nil)
        observer.isEnabled = false
      }
    }

    return producer
  }
}

#endif
