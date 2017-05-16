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

  /// **Internal use only** `NotificationsObserver` is an object for managing KVO.
  final class NotificationsObserver<T: NSObject>: ObservationSessionItem {
    typealias ObservationBlock = (Notification) -> Void
    typealias EnablingCallback = (_ notificationCenter: NotificationCenter, _ object: T?, _ isEnabled: Bool) -> Void

    let notificationCenter: NotificationCenter
    weak var object: T?
    let objectRef: Unmanaged<T>?
    let name: NSNotification.Name
    let observationBlock: ObservationBlock
    var observationToken: NSObjectProtocol?
    let enablingCallback: EnablingCallback
    var isEnabled: Bool {
      didSet {
        if isEnabled == oldValue {
          return
        } else if !isEnabled {
          notificationCenter.removeObserver(observationToken!)
          enablingCallback(notificationCenter, objectRef?.takeUnretainedValue(), false)
        } else if let object = object {
          observationToken = notificationCenter.addObserver(forName: name,
                                                            object: object,
                                                            queue: nil,
                                                            using: observationBlock)
          enablingCallback(notificationCenter, object, true)
        }
      }
    }

    init(notificationCenter: NotificationCenter,
         object: T?,
         name: NSNotification.Name,
         isEnabled: Bool,
         enablingCallback: @escaping EnablingCallback,
         observationBlock: @escaping ObservationBlock) {
      self.notificationCenter = notificationCenter
      self.object = object
      self.objectRef = object.map(Unmanaged.passUnretained)
      self.name = name
      self.observationBlock = observationBlock
      self.isEnabled = isEnabled
      self.enablingCallback = enablingCallback

      if isEnabled {
        observationToken = notificationCenter.addObserver(forName: name,
                                                          object: object,
                                                          queue: nil,
                                                          using: observationBlock)
        enablingCallback(notificationCenter, object, isEnabled)
      }
    }

    deinit {
      self.isEnabled = false
    }
  }

  extension NotificationCenter: ObjCInjectedRetainer {

    /// Makes a `ProducerProxy` that transforms notifications to updates
    /// Subscribe to listen to notifications. Update to post notifications
    ///
    /// - Returns: constructed `ProducerProxy`
    public func updatable<T: NSObject>(
      object: T,
      name: NSNotification.Name,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1,
      // swiftlint:disable:next line_length
      enablingCallback: @escaping ((_ notificationCenter: NotificationCenter, _ object: T, _ isEnabled: Bool) -> Void) = { (_, _, _) in }
      ) -> ProducerProxy<Notification, Void> {
      return _updatable(object: object,
                        name: name,
                        from: originalExecutor,
                        observationSession: observationSession,
                        channelBufferSize: channelBufferSize,
                        enablingCallback: { enablingCallback($0, $1!, $2) })
    }

    /// Makes a `ProducerProxy` that transforms notifications to updates
    /// Subscribe to listen to notifications. Update to post notifications
    ///
    /// - Returns: constructed `ProducerProxy`
    public func updatable(
      name: NSNotification.Name,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1,
      // swiftlint:disable:next line_length
      enablingCallback: @escaping ((_ notificationCenter: NotificationCenter, _ isEnabled: Bool) -> Void) = { (_, _) in }
      ) -> ProducerProxy<Notification, Void> {
      return _updatable(object: nil,
                        name: name,
                        from: originalExecutor,
                        observationSession: observationSession,
                        channelBufferSize: channelBufferSize,
                        enablingCallback: { enablingCallback($0, $2) })
    }

    func _updatable<T: NSObject>(
      object: T?,
      name: NSNotification.Name,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1,
      // swiftlint:disable:next line_length
      enablingCallback: @escaping ((_ notificationCenter: NotificationCenter, _ object: T?, _ isEnabled: Bool) -> Void) = { (_, _, _) in }
      ) -> ProducerProxy<Notification, Void> {

      let producer = ProducerProxy<Notification, Void>(
        updateExecutor: .immediate,
        bufferSize: channelBufferSize
      ) { [weak self] (_, event, _) in
        switch event {
        case let .update(update):
          self?.post(update)
        case .completion:
          nop()
        }
      }

      let observer = NotificationsObserver(
        notificationCenter: self,
        object: object,
        name: name,
        isEnabled: observationSession?.isEnabled ?? true,
        enablingCallback: enablingCallback
      ) { [weak producer] (notification) in
        _ = producer?.tryUpdateWithoutHandling(notification, from: nil)
      }

      observationSession?.insert(item: observer)
      self.notifyDeinit { [weak producer] in
        producer?.cancelBecauseOfDeallocatedContext(from: nil)
        observer.isEnabled = false
      }

      return producer
    }
  }
#endif
