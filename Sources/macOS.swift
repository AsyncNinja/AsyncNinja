//
//  Copyright (c) 2016-2019 Anton Mironov
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

#if os(macOS)

  import AppKit

  /// Conforms NSResponer to ObjCUIInjectedExecutionContext that allows
  /// using each NSResponder as ExecutionContext
  extension NSResponder: ObjCUIInjectedExecutionContext {
  }

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

    /// Shortcut that binds block to NSControl event
    ///
    /// - Parameters:
    ///   - context: context to bind block to
    ///   - block: block to execute on action on context
    func onAction<C: ExecutionContext>(
      context: C,
      _ block: @escaping (C, AnyObject?, Any?) -> Void) {

      self.actionChannel()
        .onUpdate(context: context) { (context, update) in
          block(context, update.sender, update.objectValue)
      }
    }
  }

  private class ActionReceiver: NSObject {
    weak var control: NSControl?
    let producer = Producer<NSControl.ActionChannelUpdate, Void>(bufferSize: 0)

    init(control: NSControl) {
      self.control = control
    }

    @objc dynamic func asyncNinjaAction(sender: AnyObject?) {
      let update: NSControl.ActionChannelUpdate = (
        sender: sender,
        objectValue: self.control?.objectValue
      )
      self.producer.update(update, from: .main)
    }
  }

// MARK: - reactive properties for NSView
public extension ReactiveProperties where Object: NSView {
  /// `ProducerProxy` that refers to read-write property `NSView.alphaValue`
  var alphaValue: ProducerProxy<CGFloat, Void> { return updatable(forKeyPath: "alphaValue", onNone: .drop) }

  /// `ProducerProxy` that refers to read-write property `NSView.isHidden`
  var isHidden: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "hidden", onNone: .drop) }

  /// `ProducerProxy` that refers to read-write property `NSView.isOpaque`
  var isOpaque: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "opaque", onNone: .drop) }
}

// MARK: - reactive properties for NSControl
public extension ReactiveProperties where Object: NSControl {
  var isEnabled: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "enabled", onNone: .drop) }

  /// `ProducerProxy` that refers to read-write property `NSControl.objectValue`
  var objectValue: ProducerProxy<Any?, Void> {
    return anyUpdatable(forBindingName: .value, initialValue: object.objectValue)
  }

  /// `ProducerProxy` that refers to read-write property `NSControl.stringValue`
  var stringValue: ProducerProxy<String?, Void> {
    return updatable(forBindingName: .value, initialValue: object.stringValue)
  }

  /// `ProducerProxy` that refers to read-write property `NSControl.attributedStringValue`
  var attributedStringValue: ProducerProxy<NSAttributedString?, Void> {
    return updatable(forBindingName: .value, initialValue: object.attributedStringValue)
  }

  /// `Channel` that refers to read-write property `NSControl.integerValue`
  var integerValue: ProducerProxy<Int?, Void> {
    return updatable(forBindingName: .value,
                     initialValue: object.integerValue,
                     transformer: { ($0 as? NSNumber)?.intValue ?? ($0 as? Int) },
                     reveseTransformer: { $0.map(NSNumber.init(integerLiteral:)) })
  }

  /// `Channel` that refers to read-write property `NSControl.floatValue`
  var floatValue: ProducerProxy<Float?, Void> {
    return updatable(forBindingName: .value,
                     initialValue: object.floatValue,
                     transformer: { ($0 as? NSNumber)?.floatValue ?? ($0 as? Float) },
                     reveseTransformer: { $0.map(NSNumber.init(value:)) })
  }

  /// `Channel` that refers to read-write property `NSControl.floatValue`
  var doubleValue: ProducerProxy<Double?, Void> {
    return updatable(forBindingName: .value,
                     initialValue: object.doubleValue,
                     transformer: { ($0 as? NSNumber)?.doubleValue ?? ($0 as? Double) },
                     reveseTransformer: { $0.map(NSNumber.init(value:)) })
  }
}

#endif
