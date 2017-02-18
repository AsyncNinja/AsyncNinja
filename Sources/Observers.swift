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

  // MARK: - regular observation
  public extension Retainer where Self: NSObject {
    /// makes channel of changes of value for specified key path
    ///
    /// - Parameter keyPath: to observe
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Returns: channel new values
    func changes<T>(of keyPath: String, channelBufferSize: Int = 1) -> Channel<T?, Void> {
      return changesDictionary(of: keyPath, options: [.initial, .new])
        .map(executor: .immediate) { $0[.newKey] as? T }
    }

    /// makes channel of changes of value for specified key path
    ///
    /// - Parameter keyPath: to observe
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Returns: channel of pairs (old, new) values
    func changesOldAndNew<T>(of keyPath: String, channelBufferSize: Int = 1) -> Channel<(old: T?, new: T?), Void> {
      return changesDictionary(of: keyPath, options: [.initial, .new, .old])
        .map(executor: .immediate) { (old: $0[.oldKey] as? T, new: $0[.newKey] as? T) }
    }

    /// makes channel of changes of value for specified key path
    ///
    /// - Parameter keyPath: to observe
    /// - Parameter channelBufferSize: size of the buffer within returned channel
    /// - Returns: channel of changes dictionaries (see Foundation KVO for details)
    func changesDictionary(
      of keyPath: String,
      options: NSKeyValueObservingOptions,
      channelBufferSize: Int = 1
      ) -> Channel<[NSKeyValueChangeKey: Any], Void> {
      let producer = Producer<[NSKeyValueChangeKey: Any], Void>(bufferSize: channelBufferSize)

      let observer = KeyPathObserver(keyPath: keyPath) {
        [weak producer] (changes) in
        producer?.send(changes)
      }
      addObserver(observer, forKeyPath: keyPath, options: options, context: nil)
      let pointerToSelf = Unmanaged.passUnretained(self)
      notifyDeinit { [weak producer] in
        producer?.cancelBecauseOfDeallocatedContext()
        pointerToSelf.takeUnretainedValue().removeObserver(observer, forKeyPath: keyPath)
      }

      return producer
    }
  }

  private class KeyPathObserver: NSObject {
    let keyPath: String
    let observationBlock: ([NSKeyValueChangeKey: Any]) -> Void

    init(keyPath: String, observationBlock: @escaping ([NSKeyValueChangeKey: Any]) -> Void) {
      self.keyPath = keyPath
      self.observationBlock = observationBlock
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
      assert(keyPath == self.keyPath)
      if let change = change {
        observationBlock(change)
      }
    }
  }
#endif

#if os(macOS)
  import AppKit

  /// NSControl improved with AsyncNinja
  public extension NSControl {
    /// Update of ActionChannel
    typealias ActionChannelUpdate = (sender: AnyObject?, objectValue: Any?)

    /// Channel that contains actions sent by the control
    typealias ActionChannel = Channel<ActionChannelUpdate, Void>

    /// Makes or returns cached channel. The channel that will have update on each triggering of action
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

  private class ActionReceiver: NSObject {
    weak var control: NSControl?
    let producer = Producer<NSControl.ActionChannelUpdate, Void>(bufferSize: 0)

    init(control: NSControl) {
      self.control = control
    }

    dynamic func asyncNinjaAction(sender: AnyObject?) {
      let update: NSControl.ActionChannelUpdate = (
        sender: sender,
        objectValue: self.control?.objectValue
      )
      self.producer.send(update)
    }
  }
#endif

#if os(iOS) || os(tvOS)
  import UIKit

  /// UIControl improved with AsyncNinja
  public extension UIControl {
    /// Update of ActionChannel
    typealias ActionChannelUpdate = (sender: AnyObject?, event: UIEvent)

    /// Channel that contains actions sent by the control
    typealias ActionChannel = Channel<ActionChannelUpdate, Void>

    /// Makes channel that will have update value on each triggering of action
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

  private class ActionReceiver: NSObject {
    weak var control: UIControl?
    let producer = Producer<UIControl.ActionChannelUpdate, Void>(bufferSize: 0)

    init(control: UIControl) {
      self.control = control
    }

    dynamic func asyncNinjaAction(sender: AnyObject?, forEvent event: UIEvent) {
      let update: UIControl.ActionChannelUpdate = (
        sender: sender,
        event: event
      )
      self.producer.send(update)
    }
  }
#endif
