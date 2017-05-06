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
    public typealias CustomGetter<T> = (Self) -> T?
    public typealias CustomSetter<T> = (Self, T) -> Void

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
    /// - Returns: an `UpdatableProperty<T?>` bound to observe and update specified keyPath
    func updatable<T>(
      forKeyPath keyPath: String,
      executor: Executor,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      allowSettingSameValue: Bool = false,
      channelBufferSize: Int = 1,
      customGetter: CustomGetter<T?>? = nil,
      customSetter: CustomSetter<T?>? = nil
      ) -> ProducerProxy<T?, Void> {
      let producer = ProducerProxy<T?, Void>(
        updateExecutor: executor,
        bufferSize: channelBufferSize
      ) { [weak self] (_, event, _) in
        switch event {
        case let .update(update):
          self?.setValue(update,
                         forKeyPath: keyPath,
                         allowSettingSameValue: allowSettingSameValue,
                         customSetter: customSetter)
        case .completion:
          nop()
        }
      }

      executor.execute(from: originalExecutor) { (_) in
        let observer = KeyPathObserver(
          object: self,
          keyPath: keyPath,
          options: [.initial, .new],
          isEnabled: observationSession?.isEnabled ?? true
        ) { [weak producer] (maybeSelf, changes) in
          guard let strongSelf = maybeSelf as? Self,
            let producer = producer
            else { return }

          let newValue = strongSelf.getValue(forKeyPath: keyPath, changes: changes, customGetter: customGetter)
          _ = producer.tryUpdateWithoutHandling(newValue, from: executor)
        }

        observationSession?.insert(item: observer)
        self.notifyDeinit {
          producer.cancelBecauseOfDeallocatedContext(from: nil)
          observer.isEnabled = false
        }
      }

      return producer
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
      executor: Executor,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      allowSettingSameValue: Bool = false,
      channelBufferSize: Int = 1,
      customGetter: CustomGetter<T>? = nil,
      customSetter: CustomSetter<T>? = nil
      ) -> ProducerProxy<T, Void> {
      let producer = ProducerProxy<T, Void>(
        updateExecutor: executor,
        bufferSize: channelBufferSize
      ) { [weak self] (_, event, _) in
        switch event {
        case let .update(update):
          self?.setValue(update,
                         forKeyPath: keyPath,
                         allowSettingSameValue: allowSettingSameValue,
                         customSetter: customSetter)
        case .completion:
          nop()
        }
      }

      executor.execute(from: originalExecutor) { _ in
        let observer = KeyPathObserver(
          object: self,
          keyPath: keyPath,
          options: [.initial, .new],
          isEnabled: observationSession?.isEnabled ?? true
        ) { [weak producer] (maybeSelf, changes) in
          guard
            let strongSelf = maybeSelf as? Self,
            let producer = producer
            else { return }
          if let update = strongSelf.getValue(forKeyPath: keyPath, changes: changes, customGetter: customGetter) {
            _ = producer.tryUpdateWithoutHandling(update, from: executor)
          } else if case let .replace(update) = onNone {
            _ = producer.tryUpdateWithoutHandling(update, from: executor)
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
    /// - Parameter executor: to subscribe and update value on
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
      executor: Executor,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1,
      customGetter: CustomGetter<T?>? = nil
      ) -> Channel<T?, Void> {

      let producer = Producer<T?, Void>(bufferSize: channelBufferSize)

      executor.execute(from: originalExecutor) { (_) in
        let observer = KeyPathObserver(
          object: self,
          keyPath: keyPath,
          options: [.initial, .new],
          isEnabled: observationSession?.isEnabled ?? true
        ) { [weak producer] (maybeSelf, changes) in
          guard
            let strongSelf = maybeSelf as? Self,
            let producer = producer
            else { return }
          let update = strongSelf.getValue(forKeyPath: keyPath, changes: changes, customGetter: customGetter)
          producer.update(update, from: executor)
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
    /// - Parameter onNone: is a policy of handling `None` (or `nil`) value
    ///   that can arrive from Key-Value observation.
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
    func updating<T>(
      forKeyPath keyPath: String,
      onNone: UpdateWithNoneHandlingPolicy<T>,
      executor: Executor,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1,
      customGetter: CustomGetter<T>? = nil
      ) -> Channel<T, Void> {
      let producer = Producer<T, Void>(bufferSize: channelBufferSize)

      executor.execute(from: originalExecutor) { (_) in
        let observer = KeyPathObserver(
          object: self,
          keyPath: keyPath,
          options: [.initial, .new],
          isEnabled: observationSession?.isEnabled ?? true
        ) { [weak producer] (maybeSelf, changes) in
          guard
            let strongSelf = maybeSelf as? Self,
            let producer = producer
            else { return }
          if let update = strongSelf.getValue(forKeyPath: keyPath, changes: changes, customGetter: customGetter) {
            producer.update(update, from: executor)
          } else if case let .replace(update) = onNone {
            producer.update(update, from: executor)
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

    /// Makes a sink that wraps specified setter
    ///
    /// - Parameter setter: to use with sink
    /// - Returns: constructed sink
    func sink<T>(executor: Executor, setter: @escaping CustomSetter<T>) -> Sink<T, Void> {
      let sink = Sink<T, Void>(
        updateExecutor: executor
      ) { [weak self] (_, event, _) in
        if let strongSelf = self, case let .update(update) = event {
          setter(strongSelf, update)
        }
      }
      self.notifyDeinit {
        sink.cancelBecauseOfDeallocatedContext(from: nil)
      }
      return sink
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
    /// - Parameter executor: to subscribe and update value on
    /// - Parameter originalExecutor: `Executor` you calling this method on.
    ///   Specifying this argument will allow to perform syncronous executions
    ///   on `strictAsync: false` `Executor`s.
    ///   Use default value or nil if you are not sure about an `Executor`
    ///   you calling this method on.
    /// - Parameter observationSession: is an object that helps to control observation
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Parameter customGetter: provides a custom getter to use instead of value(forKeyPath:) call
    /// - Returns: an `Updating<(old: T?, new: T?)>` bound to observe and update specified keyPath
    func updatingOldAndNew<T>(
      forKeyPath keyPath: String,
      executor: Executor,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1
      ) -> Channel<(old: T?, new: T?), Void> {
      return updatingChanges(forKeyPath: keyPath,
                             executor: executor,
                             from: originalExecutor,
                             options: [.initial, .old, .new],
                             observationSession: observationSession,
                             channelBufferSize: channelBufferSize)
        .map(executor: .immediate) { (old: $0[.oldKey] as? T, new: $0[.newKey] as? T) }
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
    /// - Parameter executor: to subscribe and update value on
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
      executor: Executor,
      from originalExecutor: Executor? = nil,
      options: NSKeyValueObservingOptions,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1
      ) -> Channel<[NSKeyValueChangeKey: Any], Void> {
      let producer = Producer<[NSKeyValueChangeKey: Any], Void>(bufferSize: channelBufferSize)

      executor.execute(from: originalExecutor) { (_) in
        let observer = KeyPathObserver(
          object: self,
          keyPath: keyPath,
          options: options,
          isEnabled: observationSession?.isEnabled ?? true
        ) { [weak producer] (_, changes) in
          producer?.update(changes, from: executor)
        }

        observationSession?.insert(item: observer)
        self.notifyDeinit {
          producer.cancelBecauseOfDeallocatedContext(from: nil)
          observer.isEnabled = false
        }
      }

      return producer
    }

    fileprivate func setValue<T>(
      _ newValue: T,
      forKeyPath keyPath: String,
      allowSettingSameValue: Bool,
      customSetter: CustomSetter<T>?) {
      let nsNewObjectValue: NSObject?
      if let customSetter = customSetter {
        customSetter(self, newValue)
      } else {
        let mustSet: Bool
        nsNewObjectValue = newValue as? NSObject

        if allowSettingSameValue {
          mustSet = true
        } else {
          let nsOldObjectValue = self
            .value(forKeyPath: keyPath)
            .map { $0 as! NSObject }
          mustSet = (nsNewObjectValue != nsOldObjectValue)
        }

        if mustSet {
          self.setValue(nsNewObjectValue, forKeyPath: keyPath)
        }
      }
    }

    fileprivate func getValue<T>(
      forKeyPath keyPath: String,
      changes: [NSKeyValueChangeKey: Any],
      customGetter: CustomGetter<T>?
      ) -> T? {
        if let customGetter = customGetter {
            return customGetter(self)
        } else {
            return changes[.newKey] as? T
        }
    }

    fileprivate func getValue<T>(
      forKeyPath keyPath: String,
      changes: [NSKeyValueChangeKey: Any],
      customGetter: CustomGetter<T?>?
      ) -> T? {
      if let customGetter = customGetter {
        return customGetter(self).flatMap { $0 }
      } else {
        return changes[.newKey] as? T
      }
    }
  }
#endif
