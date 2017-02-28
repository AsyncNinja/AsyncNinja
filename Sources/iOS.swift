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

#if os(iOS) || os(tvOS)

  import UIKit
  
  /// Conforms UIResponder to ObjCUIInjectedExecutionContext that allows
  /// using each UIResponder as ExecutionContext
  extension UIResponder: ObjCUIInjectedExecutionContext {
  }
  
  /// UIControl improved with AsyncNinja
  public extension UIControl {
    /// Update of ActionChannel
    typealias ActionChannelUpdate = (sender: AnyObject?, event: UIEvent)
    
    /// Channel that contains actions sent by the control
    typealias ActionChannel = Updating<ActionChannelUpdate>
    
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
        actionReceiver.producer.cancelBecauseOfDeallocatedContext(from: nil)
      }
      
      return actionReceiver.producer
    }
    
    /// Shortcut that binds block to UIControl event
    ///
    /// - Parameters:
    ///   - events: events to react on
    ///   - context: context to bind block to
    ///   - block: block to execute on action on context
    func onAction<C: ExecutionContext>(
      forEvents events: UIControlEvents = UIControlEvents.allEvents,
      context: C,
      _ block: @escaping (C, AnyObject?, UIEvent) -> Void) {
      
      self.actionChannel(forEvents: events)
        .onUpdate(context: context) { (context, update) in
          block(context, update.sender, update.event)
      }
    }
  }
  
  private class ActionReceiver: NSObject {
    weak var control: UIControl?
    let producer = Updatable<UIControl.ActionChannelUpdate>(bufferSize: 0)
    
    init(control: UIControl) {
      self.control = control
    }
    
    dynamic func asyncNinjaAction(sender: AnyObject?, forEvent event: UIEvent) {
      let update: UIControl.ActionChannelUpdate = (
        sender: sender,
        event: event
      )
      self.producer.update(update, from: .main)
    }
  }

  public extension ReactiveProperties where Object: UIView {
    /// An `UpdatableProperty` that refers to read-write property `UIView.alpha`
    var alpha: UpdatableProperty<CGFloat> { return updatable(forKeyPath: "alpha", onNone: .drop) }
   
    /// An `UpdatableProperty` that refers to read-write property `UIView.isHidden`
    var isHidden: UpdatableProperty<Bool> { return updatable(forKeyPath: "hidden", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UIView.isOpaque`
    var isOpaque: UpdatableProperty<Bool> { return updatable(forKeyPath: "opaque", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UIView.isUserInteractionEnabled`
    var isUserInteractionEnabled: UpdatableProperty<Bool> { return updatable(forKeyPath: "userInteractionEnabled", onNone: .drop) }
  }
  
  public extension ReactiveProperties where Object: UIControl {
    /// An `UpdatableProperty` that refers to read-write property `UIControl.isEnabled`
    var isEnabled: UpdatableProperty<Bool> { return updatable(forKeyPath: "enabled", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UIControl.isSelected`
    var isSelected: UpdatableProperty<Bool> { return updatable(forKeyPath: "selected", onNone: .drop) }

    /// An `Updating` that refers to read-only property `UIControl.state`
    var state: Updating<UIControlState> { return updatable(forKeyPath: "state", onNone: .drop) }
  }

  public extension ReactiveProperties where Object: UITextField {
    /// An `UpdatableProperty` that refers to read-write property `UITextField.text`
    var text: UpdatableProperty<String> { return updatable(forKeyPath: "text", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UITextField.attributedText`
    var attributedText: UpdatableProperty<NSAttributedString?> { return updatable(forKeyPath: "attributedText") }
    
    /// An `UpdatableProperty` that refers to read-write property `UITextField.textColor`
    var textColor: UpdatableProperty<UIColor?> { return updatable(forKeyPath: "textColor") }

    /// An `UpdatableProperty` that refers to read-write property `UITextField.font`
    var font: UpdatableProperty<UIFont> { return updatable(forKeyPath: "font", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UITextField.textAlignment`
    var textAlignment: UpdatableProperty<NSTextAlignment> {
      return updatable(forKeyPath: "textAlignment", onNone: .drop,
                       customGetter: { $0.textAlignment },
                       customSetter: {
                        if let newValue = $1 {
                          $0.textAlignment = newValue
                        }
      })
    }

    /// An `UpdatableProperty` that refers to read-write property `UITextField.placeholder`
    var placeholder: UpdatableProperty<String?> { return updatable(forKeyPath: "placeholder") }

    /// An `UpdatableProperty` that refers to read-write property `UITextField.attributedPlaceholder`
    var attributedPlaceholder: UpdatableProperty<NSAttributedString?> { return updatable(forKeyPath: "attributedPlaceholder") }

    /// An `UpdatableProperty` that refers to read-write property `UITextField.background`
    var background: UpdatableProperty<UIImage?> { return updatable(forKeyPath: "background") }
    
    /// An `UpdatableProperty` that refers to read-write property `UITextField.disabledBackground`
    var disabledBackground: UpdatableProperty<UIImage?> { return updatable(forKeyPath: "disabledBackground") }

    /// An `Updating` that refers to read-only property `UITextField.isEditing`
    var isEditing: Updating<Bool> { return updating(forKeyPath: "disabledBackground", onNone: .drop) }
  }

  public extension ReactiveProperties where Object: UIViewController {
    /// An `UpdatableProperty` that refers to read-write property `UIViewController.title`
    var title: UpdatableProperty<String?> { return updatable(forKeyPath: "title") }
  }
#endif
