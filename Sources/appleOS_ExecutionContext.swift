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
    /// a getter that could be provided as customization point
    typealias CustomGetter<T> = (Self) -> T?
    /// a setter that could be provided as customization point
    typealias CustomSetter<T> = (Self, T) -> Void

    /// makes an `UpdatableProperty<T?>` for specified key path.
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
    /// - Parameter originalExecutor: `Executor` you calling this method on.
    ///   Specifying this argument will allow to perform syncronous executions
    ///   on `strictAsync: false` `Executor`s.
    ///   Use default value or nil if you are not sure about an `Executor`
    ///   you calling this method on.
    /// - Parameter observationSession: is an object that helps to control observation
    /// - Parameter allowSettingSameValue: set to true if you want
    ///   to set a new value event if it is equal to an old one
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Parameter customGetter: provides a custom getter to use instead of value(forKeyPath:) call
    /// - Parameter customSetter: provides a custom getter to use instead of setValue(_: forKeyPath:) call
    /// - Returns: an `UpdatableProperty<T?>` bound to observe and update specified keyPath
    func updatable<T>(
      forKeyPath keyPath: String,
      from originalExecutor: Executor?,
      observationSession: ObservationSession? = nil,
      allowSettingSameValue: Bool = false,
      channelBufferSize: Int = 1,
      customGetter: CustomGetter<T?>? = nil,
      customSetter: CustomSetter<T?>? = nil
      ) -> ProducerProxy<T?, Void> {
      return updatable(forKeyPath: keyPath,
                       executor: executor,
                       from: originalExecutor,
                       observationSession: observationSession,
                       allowSettingSameValue: allowSettingSameValue,
                       channelBufferSize: channelBufferSize,
                       customGetter: customGetter,
                       customSetter: customSetter)
    }

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
    /// - Parameter onNone: is a policy of handling `None` (or `nil`) value
    ///   that can arrive from Key-Value observation.
    /// - Parameter executor: to subscribe and update value on
    /// - Parameter originalExecutor: `Executor` you calling this method on.
    ///   Specifying this argument will allow to perform syncronous executions
    ///   on `strictAsync: false` `Executor`s.
    ///   Use default value or nil if you are not sure about an `Executor`
    ///   you calling this method on.
    /// - Parameter observationSession: is an object that helps to control observation
    /// - Parameter allowSettingSameValue: set to true if you want
    ///   to set a new value event if it is equal to an old one
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Parameter customGetter: provides a custom getter to use instead of value(forKeyPath:) call
    /// - Parameter customSetter: provides a custom getter to use instead of setValue(_: forKeyPath:) call
    /// - Returns: an `UpdatableProperty<T>` bound to observe and update specified keyPath
    func updatable<T>(
      forKeyPath keyPath: String,
      onNone: UpdateWithNoneHandlingPolicy<T>,
      from originalExecutor: Executor?,
      observationSession: ObservationSession? = nil,
      allowSettingSameValue: Bool = false,
      channelBufferSize: Int = 1,
      customGetter: CustomGetter<T>? = nil,
      customSetter: CustomSetter<T>? = nil
      ) -> ProducerProxy<T, Void> {
      return updatable(forKeyPath: keyPath,
                       onNone: onNone,
                       executor: executor,
                       from: originalExecutor,
                       observationSession: observationSession,
                       allowSettingSameValue: allowSettingSameValue,
                       channelBufferSize: channelBufferSize,
                       customGetter: customGetter,
                       customSetter: customSetter)
    }

    /// makes an `Updating<T?>` for specified key path.
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
    /// - Parameter originalExecutor: `Executor` you calling this method on.
    ///   Specifying this argument will allow to perform syncronous executions
    ///   on `strictAsync: false` `Executor`s.
    ///   Use default value or nil if you are not sure about an `Executor`
    ///   you calling this method on.
    /// - Parameter observationSession: is an object that helps to control observation
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Parameter customGetter: provides a custom getter to use instead of value(forKeyPath:) call
    /// - Returns: an `Updating<T?>` bound to observe and update specified keyPath
    func updating<T>(
      forKeyPath keyPath: String,
      from originalExecutor: Executor?,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1,
      customGetter: CustomGetter<T?>? = nil
      ) -> Channel<T?, Void> {
      return updating(forKeyPath: keyPath,
                      executor: executor,
                      from: originalExecutor,
                      observationSession: observationSession,
                      channelBufferSize: channelBufferSize,
                      customGetter: customGetter)
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
    /// - Parameter onNone: is a policy of handling `None` (or `nil`) value
    ///   that can arrive from Key-Value observation.
    /// - Parameter originalExecutor: `Executor` you calling this method on.
    ///   Specifying this argument will allow to perform syncronous executions
    ///   on `strictAsync: false` `Executor`s.
    ///   Use default value or nil if you are not sure about an `Executor`
    ///   you calling this method on.
    /// - Parameter observationSession: is an object that helps to control observation
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Parameter customGetter: provides a custom getter to use instead of value(forKeyPath:) call
    /// - Returns: an `Updating<T>` bound to observe and update specified keyPath
    func updating<T>(
      forKeyPath keyPath: String,
      onNone: UpdateWithNoneHandlingPolicy<T>,
      from originalExecutor: Executor?,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1,
      customGetter: CustomGetter<T>? = nil
      ) -> Channel<T, Void> {

      return updating(forKeyPath: keyPath,
                      onNone: onNone,
                      executor: executor,
                      from: originalExecutor,
                      observationSession: observationSession,
                      channelBufferSize: channelBufferSize,
                      customGetter: customGetter)
    }

    /// makes an `Updating<(old: T?, new: T?)>` for specified key path.
    /// With an `Updating` you can
    /// * subscribe for updates
    /// * transform `Updating` as any `Channel` (`map`, `flatMap`, `filter`, `debounce`, `distinct`, ...)
    ///
    /// - Parameter keyPath: to observe.
    ///
    ///   **Make sure that keyPath refers to KVO-compliant property**.
    ///   * Make sure that properties defined in swift have dynamic attribute.
    ///   * Make sure that methods `class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String>`
    ///   return correct values for read-only properties
    /// - Parameter originalExecutor: `Executor` you calling this method on.
    ///   Specifying this argument will allow to perform syncronous executions
    ///   on `strictAsync: false` `Executor`s.
    ///   Use default value or nil if you are not sure about an `Executor`
    ///   you calling this method on.
    /// - Parameter observationSession: is an object that helps to control observation
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Returns: an `Updating<(old: T?, new: T?)>` bound to observe and update specified keyPath
    func updatingOldAndNew<T>(
      forKeyPath keyPath: String,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1
      ) -> Channel<(old: T?, new: T?), Void> {
      return updatingOldAndNew(forKeyPath: keyPath,
                               executor: executor,
                               observationSession: observationSession,
                               channelBufferSize: channelBufferSize)
    }

    /// makes an `Updating<[NSKeyValueChangeKey: Any]>` for specified key path.
    /// With an `Updating` you can
    /// * subscribe for updates
    /// * transform `Updating` as any `Channel` (`map`, `flatMap`, `filter`, `debounce`, `distinct`, ...)
    ///
    /// - Parameter keyPath: to observe.
    ///
    ///   **Make sure that keyPath refers to KVO-compliant property**.
    ///   * Make sure that properties defined in swift have dynamic attribute.
    ///   * Make sure that methods `class func keyPathsForValuesAffectingValue(forKey key: String) -> Set<String>`
    ///   return correct values for read-only properties
    /// - Parameter originalExecutor: `Executor` you calling this method on.
    ///   Specifying this argument will allow to perform syncronous executions
    ///   on `strictAsync: false` `Executor`s.
    ///   Use default value or nil if you are not sure about an `Executor`
    ///   you calling this method on.
    /// - Parameter observationSession: is an object that helps to control observation
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Returns: an `Updating<[NSKeyValueChangeKey: Any]>` bound to observe and update specified keyPath
    func updatingChanges(
      forKeyPath keyPath: String,
      from originalExecutor: Executor? = nil,
      options: NSKeyValueObservingOptions,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1
      ) -> Channel<[NSKeyValueChangeKey: Any], Void> {
      return updatingChanges(forKeyPath: keyPath,
                             executor: executor,
                             from: originalExecutor,
                             options: options,
                             observationSession: observationSession,
                             channelBufferSize: channelBufferSize)
    }

    /// Makes a sink that wraps specified setter
    ///
    /// - Parameter setter: to use with sink
    /// - Returns: constructed sink
    func sink<T>(setter: @escaping CustomSetter<T>) -> Sink<T, Void> {
      return sink(executor: executor, setter: setter)
    }
  }
#endif
