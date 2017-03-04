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
  final class NotificationsObserver: ObservationSessionItem {
    typealias ObservationBlock = (Notification) -> Void
    
    let notificationCenter: NotificationCenter
    weak var object: NSObject?
    let name: NSNotification.Name
    let observationBlock: ObservationBlock
    var observationToken: NSObjectProtocol? = nil
    var isEnabled: Bool {
      didSet {
        if isEnabled == oldValue {
          return
        } else if isEnabled {
          observationToken = notificationCenter.addObserver(forName: name,
                                                            object: object,
                                                            queue: nil,
                                                            using: observationBlock)
        } else {
          notificationCenter.removeObserver(observationToken!)
        }
      }
    }
    
    init(notificationCenter: NotificationCenter,
         object: NSObject?,
         name: NSNotification.Name,
         isEnabled: Bool,
         observationBlock: @escaping ObservationBlock) {
      self.notificationCenter = notificationCenter
      self.object = object
      self.name = name
      self.observationBlock = observationBlock
      self.isEnabled = isEnabled
      
      if isEnabled {
        observationToken = notificationCenter.addObserver(forName: name,
                                                          object: object,
                                                          queue: nil,
                                                          using: observationBlock)
      }
    }
    
    deinit {
      self.isEnabled = false
    }
  }
  
  extension NotificationCenter: ObjCInjectedRetainer {
    public func updatable(
      object: NSObject?,
      name: NSNotification.Name,
      from originalExecutor: Executor? = nil,
      observationSession: ObservationSession? = nil,
      channelBufferSize: Int = 1
      ) -> ProducerProxy<Notification, Void> {
      
      let producer = ProducerProxy<Notification, Void>(bufferSize: channelBufferSize, updateExecutor: .immediate) {
        [weak self] (producerProxy, event, originalExecutor) in
        switch event {
        case let .update(update):
          self?.post(update)
        case .completion:
          nop()
        }
      }
      
      let observer = NotificationsObserver(notificationCenter: self,
                                           object: object,
                                           name: name,
                                           isEnabled: observationSession?.isEnabled ?? true)
      {
        [weak producer] (notification) in
        producer?.updateWithoutHandling(notification, from: nil)
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
