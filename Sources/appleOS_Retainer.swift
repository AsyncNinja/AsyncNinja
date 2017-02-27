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
    /// - Returns: an `UpdatableProperty<T?>` bound to observe and update specified keyPath
    func updatable<T>(
      for keyPath: String,
      executor: Executor,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      allowSettingSameValue: Bool = false,
      channelBufferSize: Int = 1
      ) -> UpdatableProperty<T?> {
      let producer = UpdatableProperty<T?>(bufferSize: channelBufferSize, updateExecutor: executor) {
        [weak self] (producerProxy, event, originalExecutor) in
        switch event {
        case let .update(update):
          if allowSettingSameValue {
            self?.setValue(update, forKey: keyPath)
          } else if let strongSelf = self {
            let nsObjectUpdate = update.map { $0 as! NSObject }
            let nsObjectValue = strongSelf.value(forKeyPath: keyPath).map { $0 as! NSObject }
            if nsObjectUpdate != nsObjectValue {
              strongSelf.setValue(update, forKey: keyPath)
            }
          }
        case .completion:
          nop()
        }
      }

      executor.execute(from: originalExecutor) { (originalExecutor) in
        let observer = KeyPathObserver(object: self, keyPath: keyPath, options: [.initial, .old, .new], enabled: observationSession?.enabled ?? true) {
          [weak producer] (changes) in
          producer?.updateWithoutHandling(changes[.newKey] as? T, from: executor)
        }

        observationSession?.observers.push(observer)
        self.notifyDeinit { [weak producer] in
          producer?.cancelBecauseOfDeallocatedContext(from: nil)
          observer.enabled = false
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
    /// - Returns: an `UpdatableProperty<T>` bound to observe and update specified keyPath
    func updatable<T>(
      for keyPath: String,
      onNone: UpdateWithNoneHandlingPolicy<T>,
      executor: Executor,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      allowSettingSameValue: Bool = false,
      channelBufferSize: Int = 1
      ) -> UpdatableProperty<T> {
      let producer = UpdatableProperty<T>(bufferSize: channelBufferSize, updateExecutor: executor) {
        [weak self] (producerProxy, event, originalExecutor) in
        switch event {
        case let .update(update):
          if allowSettingSameValue {
            self?.setValue(update, forKey: keyPath)
          } else if let strongSelf = self {
            let nsObjectUpdate = update as! NSObject
            let nsObjectValue = strongSelf.value(forKeyPath: keyPath).map { $0 as! NSObject }
            if nsObjectUpdate != nsObjectValue {
              strongSelf.setValue(update, forKey: keyPath)
            }
          }
        case .completion:
          nop()
        }
      }
      
      executor.execute(from: originalExecutor) { (originalExecutor) in
        let observer = KeyPathObserver(object: self, keyPath: keyPath, options: [.initial, .old, .new], enabled: observationSession?.enabled ?? true) {
          [weak producer] (changes) in
          if let update = changes[.newKey] as? T {
            producer?.updateWithoutHandling(update, from: executor)
          } else if case let .replace(update) = onNone {
            producer?.updateWithoutHandling(update, from: executor)
          }
        }
        
        observationSession?.observers.push(observer)
        self.notifyDeinit { [weak producer] in
          producer?.cancelBecauseOfDeallocatedContext(from: nil)
          observer.enabled = false
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
    /// - Returns: an `Updating<T?>` bound to observe and update specified keyPath
    func updating<T>(
      for keyPath: String,
      executor: Executor,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1
      ) -> Updating<T?> {
      return updatingChanges(for: keyPath,
                             executor: executor,
                             from: originalExecutor,
                             options: [.initial, .old, .new],
                             observationSession: observationSession,
                             channelBufferSize: channelBufferSize)
        .map(executor: .immediate) { $0[.newKey] as? T }
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
    /// - Returns: an `Updating<T>` bound to observe and update specified keyPath
    func updating<T>(
      for keyPath: String,
      onNone: UpdateWithNoneHandlingPolicy<T>,
      executor: Executor,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1
      ) -> Updating<T> {
      return updatingChanges(for: keyPath,
                             executor: executor,
                             from: originalExecutor,
                             options: [.initial, .old, .new],
                             observationSession: observationSession,
                             channelBufferSize: channelBufferSize)
        .flatMap(executor: .immediate) { (changes) -> T? in
          if let update = changes[.newKey] as? T {
            return update
          } else if case let .replace(update) = onNone {
            return update
          } else {
            return nil
          }
      }
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
    /// - Returns: an `Updating<(old: T?, new: T?)>` bound to observe and update specified keyPath
    func updatingOldAndNew<T>(
      for keyPath: String,
      executor: Executor,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1
      ) -> Updating<(old: T?, new: T?)> {
      return updatingChanges(for: keyPath,
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
      for keyPath: String,
      executor: Executor,
      from originalExecutor: Executor? = nil,
      options: NSKeyValueObservingOptions,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1
      ) -> Updating<[NSKeyValueChangeKey: Any]> {
      let producer = Updatable<[NSKeyValueChangeKey: Any]>(bufferSize: channelBufferSize)

      executor.execute(from: originalExecutor) { (originalExecutor) in
        let observer = KeyPathObserver(object: self,
                                       keyPath: keyPath,
                                       options: options,
                                       enabled: observationSession?.enabled ?? true)
        {
          [weak producer] (changes) in
          producer?.update(changes, from: executor)
        }

        observationSession?.observers.push(observer)
        self.notifyDeinit { [weak producer] in
          producer?.cancelBecauseOfDeallocatedContext(from: nil)
          observer.enabled = false
        }
      }

      return producer
    }
  }
#endif
