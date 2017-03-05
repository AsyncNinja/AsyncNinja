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
    let producer = Producer<UIControl.ActionChannelUpdate, Void>(bufferSize: 0)
    
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
    var alpha: ProducerProxy<CGFloat, Void> { return updatable(forKeyPath: "alpha", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UIView.tintColor`
    var tintColor: ProducerProxy<UIColor, Void> { return updatable(forKeyPath: "tintColor", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UIView.isHidden`
    var isHidden: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "hidden", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UIView.isOpaque`
    var isOpaque: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "opaque", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UIView.isUserInteractionEnabled`
    var isUserInteractionEnabled: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "userInteractionEnabled", onNone: .drop) }
  }
  
  public extension ReactiveProperties where Object: UIControl {
    /// An `UpdatableProperty` that refers to read-write property `UIControl.isEnabled`
    var isEnabled: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "enabled", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UIControl.isSelected`
    var isSelected: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "selected", onNone: .drop) }

    /// An `Updating` that refers to read-only property `UIControl.state`
    var state: ProducerProxy<UIControlState, Void> { return updatable(forKeyPath: "state", onNone: .drop) }
  }

  public extension ReactiveProperties where Object: UITextField {
    /// An `UpdatableProperty` that refers to read-write property `UITextField.text`
    var text: ProducerProxy<String, Void> { return updatable(forKeyPath: "text", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UITextField.attributedText`
    var attributedText: ProducerProxy<NSAttributedString?, Void> { return updatable(forKeyPath: "attributedText") }
    
    /// An `UpdatableProperty` that refers to read-write property `UITextField.textColor`
    var textColor: ProducerProxy<UIColor?, Void> { return updatable(forKeyPath: "textColor") }

    /// An `UpdatableProperty` that refers to read-write property `UITextField.font`
    var font: ProducerProxy<UIFont, Void> { return updatable(forKeyPath: "font", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UITextField.textAlignment`
    var textAlignment: ProducerProxy<NSTextAlignment, Void> {
      return updatable(forKeyPath: "textAlignment", onNone: .drop,
                       customGetter: { $0.textAlignment },
                       customSetter: { $0.textAlignment = $1 })
    }

    /// An `UpdatableProperty` that refers to read-write property `UITextField.placeholder`
    var placeholder: ProducerProxy<String?, Void> { return updatable(forKeyPath: "placeholder") }

    /// An `UpdatableProperty` that refers to read-write property `UITextField.attributedPlaceholder`
    var attributedPlaceholder: ProducerProxy<NSAttributedString?, Void> { return updatable(forKeyPath: "attributedPlaceholder") }

    /// An `UpdatableProperty` that refers to read-write property `UITextField.background`
    var background: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "background") }
    
    /// An `UpdatableProperty` that refers to read-write property `UITextField.disabledBackground`
    var disabledBackground: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "disabledBackground") }

    /// An `Updating` that refers to read-only property `UITextField.isEditing`
    var isEditing: Channel<Bool, Void> { return updating(forKeyPath: "isEditing", onNone: .drop) }
  }

  public extension ReactiveProperties where Object: UISearchBar {
    /// An `UpdatableProperty` that refers to read-write property `UISearchBar.barStyle`
    var barStyle: ProducerProxy<UIBarStyle, Void> {
      return updatable(forKeyPath: "barStyle",
                       onNone: .drop,
                       customGetter: { $0.barStyle },
                       customSetter: { $0.barStyle = $1 })
    }

    /// An `UpdatableProperty` that refers to read-write property `UISearchBar.text`
    var text: ProducerProxy<String, Void> { return updatable(forKeyPath: "text", onNone: .drop) }
    
    /// An `UpdatableProperty` that refers to read-write property `UISearchBar.prompt`
    var prompt: ProducerProxy<String?, Void> { return updatable(forKeyPath: "prompt") }
    
    /// An `UpdatableProperty` that refers to read-write property `UISearchBar.placeholder`
    var placeholder: ProducerProxy<String?, Void> { return updatable(forKeyPath: "placeholder") }

    /// An `UpdatableProperty` that refers to read-write property `UISearchBar.showsBookmarkButton`
    var showsBookmarkButton: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "showsBookmarkButton", onNone: .drop) }
    
    /// An `UpdatableProperty` that refers to read-write property `UISearchBar.showsCancelButton`
    var showsCancelButton: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "showsCancelButton", onNone: .drop) }
    
    /// An `UpdatableProperty` that refers to read-write property `UISearchBar.showsSearchResultsButton`
    var showsSearchResultsButton: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "showsSearchResultsButton", onNone: .drop) }
    
    /// An `UpdatableProperty` that refers to read-write property `UISearchBar.isSearchResultsButtonSelected`
    var isSearchResultsButtonSelected: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "searchResultsButtonSelected", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UISearchBar.barTintColor`
    var barTintColor: ProducerProxy<UIColor, Void> { return updatable(forKeyPath: "barTintColor", onNone: .drop) }
    
    /// An `UpdatableProperty` that refers to read-write property `UISearchBar.searchBarStyle`
    var searchBarStyle: ProducerProxy<UISearchBarStyle, Void> {
      return updatable(forKeyPath: "searchBarStyle",
                       onNone: .drop,
                       customGetter: { $0.searchBarStyle },
                       customSetter: { $0.searchBarStyle = $1 })
    }
  }

  public extension ReactiveProperties where Object: UIImageView {
    /// An `UpdatableProperty` that refers to read-write property `UIImageView.image`
    var image: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "image") }
    
    /// An `UpdatableProperty` that refers to read-write property `UIImageView.highlightedImage`
    var highlightedImage: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "highlightedImage") }
    
    /// An `UpdatableProperty` that refers to read-write property `UIImageView.isHighlighted`
    var isHighlighted: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "highlighted", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UIImageView.animationImages`
    var animationImages: ProducerProxy<[UIImage]?, Void> { return updatable(forKeyPath: "animationImages") }
    
    /// An `UpdatableProperty` that refers to read-write property `UIImageView.highlightedAnimationImages`
    var highlightedAnimationImages: ProducerProxy<[UIImage]?, Void> { return updatable(forKeyPath: "highlightedAnimationImages") }
    
    /// An `UpdatableProperty` that refers to read-write property `UIImageView.animationDuration`
    var animationDuration: ProducerProxy<TimeInterval, Void> { return updatable(forKeyPath: "animationDuration", onNone: .drop) }

    /// An `UpdatableProperty` that refers to read-write property `UIImageView.animationRepeatCount`
    var animationRepeatCount: ProducerProxy<Int, Void> { return updatable(forKeyPath: "animationRepeatCount", onNone: .drop) }
    
    /// An `UpdatableProperty` that refers to read-write property `UIImageView.isAnimating`
    var isAnimating: ProducerProxy<Bool, Void> {
      return updatable(forKeyPath: "animating",
                       onNone: .drop,
                       customGetter: { $0.isAnimating },
                       customSetter:
        {
          if $1 {
            $0.startAnimating()
          } else {
            $0.stopAnimating()
          }
      })
    }
  }

  public extension ReactiveProperties where Object: UIButton {
    func title(for state: UIControlState) -> Sink<String?, Void> {
      return sink { $0.setTitle($1, for: state) }
    }

    func titleShadowColor(for state: UIControlState) -> Sink<UIColor?, Void> {
      return sink { $0.setTitleShadowColor($1, for: state) }
    }

    func image(for state: UIControlState) -> Sink<UIImage?, Void> {
      return sink { $0.setImage($1, for: state) }
    }

    func backgroundImage(for state: UIControlState) -> Sink<UIImage?, Void> {
      return sink { $0.setBackgroundImage($1, for: state) }
    }

    func attributedTitle(for state: UIControlState) -> Sink<NSAttributedString?, Void> {
      return sink { $0.setAttributedTitle($1, for: state) }
    }
  }

  public extension ReactiveProperties where Object: UIViewController {
    /// An `UpdatableProperty` that refers to read-write property `UIViewController.title`
    var title: ProducerProxy<String?, Void> { return updatable(forKeyPath: "title") }
  }
#endif
