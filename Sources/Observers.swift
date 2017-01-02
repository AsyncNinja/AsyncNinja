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

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  import Foundation

  // MARK: - regular observation
  public extension Retainer where Self: NSObject {
    /// makes channel of changes of value for specified key path
    ///
    /// - Parameter keyPath: to observe
    /// - Returns: channel
    func changes<T>(of keyPath: String) -> Channel<T?, Void> {
      let producer = Producer<T?, Void>(bufferSize: 1)
      let observer = KeyPathObserver<T>(keyPath: keyPath, producer: producer)
      self.addObserver(observer, forKeyPath: keyPath, options: [.initial, .new], context: nil)

      let pointerToSelf = Unmanaged.passUnretained(self)
      self.notifyDeinit { [weak producer] in
        producer?.cancelBecauseOfDeallocatedContext()
        pointerToSelf.takeUnretainedValue().removeObserver(observer, forKeyPath: keyPath)
      }

      return producer
    }
  }

  private class KeyPathObserver<T> : NSObject {
    let keyPath: String
    weak var producer: Producer<T?, Void>?

    init(keyPath: String, producer: Producer<T?, Void>) {
      self.keyPath = keyPath
      self.producer = producer
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
      assert(keyPath == self.keyPath)
      guard
        let producer = self.producer,
        let change = change
        else { return }

      producer.send(change[.newKey] as? T)
    }
  }
#endif

#if os(macOS)
  import AppKit

  /// NSControl improved with AsyncNinja
  public extension NSControl {
    /// PeriodicValue of ActionChannel
    typealias ActionChannelPeriodicValue = (sender: AnyObject?, objectValue: Any?)

    /// Channel that contains actions sent by the control
    typealias ActionChannel = Channel<ActionChannelPeriodicValue, Void>

    /// Makes or returns cached channel. The chennel that will have periodic on each triggering of action
    func actionChannel() -> ActionChannel {
      let actionReceiver = (self.target as? ActionReceiver) ?? {
        let actionReceiver = ActionReceiver(control: self)
        self.target = actionReceiver
        self.notifyDeinit {
          actionReceiver.producer.cancelBecauseOfDeallocatedContext()
        }
        return actionReceiver
        }()

      self.action = #selector(ActionReceiver.asyncNinjaAction(sender:))
      return actionReceiver.producer
    }
  }

  private class ActionReceiver : NSObject {
    weak var control: NSControl?
    let producer = Producer<NSControl.ActionChannelPeriodicValue, Void>(bufferSize: 0)

    init(control: NSControl) {
      self.control = control
    }

    dynamic func asyncNinjaAction(sender: AnyObject?) {
      let periodicValue: NSControl.ActionChannelPeriodicValue = (
        sender: sender,
        objectValue: self.control?.objectValue
      )
      self.producer.send(periodicValue)
    }
  }
#endif

#if os(iOS) || os(tvOS)
  import UIKit

  /// UIControl improved with AsyncNinja
  public extension UIControl {
    /// PeriodicValue of ActionChannel
    typealias ActionChannelPeriodicValue = (sender: AnyObject?, event: UIEvent)

    /// Channel that contains actions sent by the control
    typealias ActionChannel = Channel<ActionChannelPeriodicValue, Void>

    /// Makes channel that will have periodic value on each triggering of action
    ///
    /// - Parameter events: events that to listen for
    /// - Returns: unbuffered channel
    func actionChannel(forEvents events: UIControlEvents = UIControlEvents.allEvents) -> ActionChannel {
      let actionReceiver = ActionReceiver(control: self)
      self.addTarget(actionReceiver,
                     action: #selector(ActionReceiver.asyncNinjaAction(sender:forEvent:)),
                     for: events)
      self.notifyDeinit {
        actionReceiver.producer.cancelBecauseOfDeallocatedContext()
      }

      return actionReceiver.producer
    }
  }

  private class ActionReceiver : NSObject {
    weak var control: UIControl?
    let producer = Producer<UIControl.ActionChannelPeriodicValue, Void>(bufferSize: 0)

    init(control: UIControl) {
      self.control = control
    }

    dynamic func asyncNinjaAction(sender: AnyObject?, forEvent event: UIEvent) {
      let periodicValue: UIControl.ActionChannelPeriodicValue = (
        sender: sender,
        event: event
      )
      self.producer.send(periodicValue)
    }
  }
#endif
