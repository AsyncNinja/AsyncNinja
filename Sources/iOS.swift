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
    var alpha: UpdatableProperty<CGFloat> { return updatable(for: "alpha", onNone: .drop) }
    var isHidden: UpdatableProperty<Bool> { return updatable(for: "hidden", onNone: .drop) }
    var isOpaque: UpdatableProperty<Bool> { return updatable(for: "opaque", onNone: .drop) }
    var isUserInteractionEnabled: UpdatableProperty<Bool> { return updatable(for: "userInteractionEnabled", onNone: .drop) }
  }
  
  public extension ReactiveProperties where Object: UIControl {
    var isEnabled: UpdatableProperty<Bool> { return updatable(for: "enabled", onNone: .drop) }
    var isSelected: UpdatableProperty<Bool> { return updatable(for: "selected", onNone: .drop) }
    var state: Updating<UIControlState> { return updatable(for: "state", onNone: .drop) }
  }

  public extension ReactiveProperties where Object: UITextField {
    var text: UpdatableProperty<String> { return updatable(for: "text", onNone: .drop) }
    var attributedText: UpdatableProperty<NSAttributedString?> { return updatable(for: "attributedText") }
    var textColor: UpdatableProperty<UIColor?> { return updatable(for: "textColor") }
    var font: UpdatableProperty<NSTextAlignment> { return updatable(for: "font", onNone: .drop) }
    var textAlignment: UpdatableProperty<NSTextAlignment> { return updatable(for: "textAlignment", onNone: .drop) }
    var placeholder: UpdatableProperty<String?> { return updatable(for: "placeholder") }
    var attributedPlaceholder: UpdatableProperty<NSAttributedString?> { return updatable(for: "attributedPlaceholder") }
    var background: UpdatableProperty<UIImage?> { return updatable(for: "background") }
    var disabledBackground: UpdatableProperty<UIImage?> { return updatable(for: "disabledBackground") }
    var isEditing: Updating<Bool> { return updating(for: "disabledBackground", onNone: .drop) }
  }

  public extension ReactiveProperties where Object: UIViewController {
    var title: UpdatableProperty<String?> { return updatable(for: "title")
    }
  }
#endif
