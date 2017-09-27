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

  // MARK: - reactive properties for UIView
  public extension ReactiveProperties where Object: UIView {
    /// `ProducerProxy` that refers to read-write property `UIView.alpha`
    var alpha: ProducerProxy<CGFloat, Void> { return updatable(forKeyPath: "alpha", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIView.tintColor`
    var tintColor: ProducerProxy<UIColor, Void> { return updatable(forKeyPath: "tintColor", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIView.isHidden`
    var isHidden: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "hidden", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIView.isOpaque`
    var isOpaque: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "opaque", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIView.isUserInteractionEnabled`
    var isUserInteractionEnabled: ProducerProxy<Bool, Void> {
      return updatable(forKeyPath: "userInteractionEnabled", onNone: .drop)
    }
  }

  // MARK: - reactive properties for UIControl
  public extension ReactiveProperties where Object: UIControl {
    /// Makes channel that will have update value on each triggering of action
    ///
    /// - Parameter events: events that to listen for
    /// - Returns: unbuffered channel
    func actions(
      forEvents events: UIControlEvents = UIControlEvents.allEvents
      ) -> Channel<(sender: AnyObject?, event: UIEvent), Void> {
      let actionReceiver = UIControlActionReceiver(control: object)
      object.addTarget(actionReceiver,
                     action: #selector(UIControlActionReceiver.asyncNinjaAction(sender:forEvent:)),
                     for: events)
      object.notifyDeinit {
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

      self.actions(forEvents: events)
        .onUpdate(context: context) { (context, update) in
          block(context, update.sender, update.event)
      }
    }

    /// `ProducerProxy` that refers to read-write property `UIControl.isEnabled`
    var isEnabled: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "enabled", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIControl.isSelected`
    var isSelected: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "selected", onNone: .drop) }

    /// `Channel` that refers to read-only property `UIControl.state`
    var state: Channel<UIControlState, Void> { return updating(forKeyPath: "state", onNone: .drop) }
  }

  private class UIControlActionReceiver: NSObject {
    weak var control: UIControl?
    let producer = Producer<(sender: AnyObject?, event: UIEvent), Void>(bufferSize: 0)

    init(control: UIControl) {
      self.control = control
    }

    @objc dynamic func asyncNinjaAction(sender: AnyObject?, forEvent event: UIEvent) {
      let update: (sender: AnyObject?, event: UIEvent) = (
        sender: sender,
        event: event
      )
      self.producer.update(update, from: .main)
    }
  }

  // MARK: - reactive properties for UILabel
  public extension ReactiveProperties where Object: UILabel {
    /// `ProducerProxy` that refers to read-write property `UILabel.text`
    var text: ProducerProxy<String, Void> { return updatable(forKeyPath: "text", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UILabel.font`
    var font: ProducerProxy<UIFont, Void> { return updatable(forKeyPath: "font", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UILabel.textColor`
    var textColor: ProducerProxy<UIColor?, Void> { return updatable(forKeyPath: "textColor") }

    /// `ProducerProxy` that refers to read-write property `UILabel.shadowColor`
    var shadowColor: ProducerProxy<UIColor?, Void> { return updatable(forKeyPath: "shadowColor") }

    /// `ProducerProxy` that refers to read-write property `UILabel.shadowOffset`
    var shadowOffset: ProducerProxy<CGSize, Void> {
      return updatable(forKeyPath: "shadowOffset",
                       onNone: .drop,
                       customGetter: { $0.shadowOffset },
                       customSetter: { $0.shadowOffset = $1 })
    }

    /// `ProducerProxy` that refers to read-write property `UILabel.textAlignment`
    var textAlignment: ProducerProxy<NSTextAlignment, Void> {
      return updatable(forKeyPath: "textAlignment",
                       onNone: .drop,
                       customGetter: { $0.textAlignment },
                       customSetter: { $0.textAlignment = $1 })
    }

    /// `ProducerProxy` that refers to read-write property `UILabel.lineBreakMode`
    var lineBreakMode: ProducerProxy<NSLineBreakMode, Void> {
      return updatable(forKeyPath: "lineBreakMode",
                       onNone: .drop,
                       customGetter: { $0.lineBreakMode },
                       customSetter: { $0.lineBreakMode = $1 })
    }

    /// `ProducerProxy` that refers to read-write property `UILabel.attributedText`
    var attributedText: ProducerProxy<NSAttributedString?, Void> { return updatable(forKeyPath: "attributedText") }

    /// `ProducerProxy` that refers to read-write property `UILabel.highlightedTextColor`
    var highlightedTextColor: ProducerProxy<UIColor?, Void> { return updatable(forKeyPath: "highlightedTextColor") }

    /// `ProducerProxy` that refers to read-write property `UILabel.isHighlighted`
    var isHighlighted: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "highlighted", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UILabel.isEnabled`
    var isEnabled: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "enabled", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UILabel.numberOfLines`
    var numberOfLines: ProducerProxy<Int, Void> { return updatable(forKeyPath: "numberOfLines", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UILabel.baselineAdjustment`
    var baselineAdjustment: ProducerProxy<UIBaselineAdjustment, Void> {
      return updatable(forKeyPath: "baselineAdjustment",
                       onNone: .drop,
                       customGetter: { $0.baselineAdjustment },
                       customSetter: { $0.baselineAdjustment = $1 })
    }
  }

  // MARK: - reactive properties for UITextField
  public extension ReactiveProperties where Object: UITextField {
    /// `ProducerProxy` that refers to read-write property `UITextField.text`
    var text: ProducerProxy<String, Void> { return updatable(forKeyPath: "text", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UITextField.attributedText`
    var attributedText: ProducerProxy<NSAttributedString?, Void> { return updatable(forKeyPath: "attributedText") }

    /// `ProducerProxy` that refers to read-write property `UITextField.textColor`
    var textColor: ProducerProxy<UIColor?, Void> { return updatable(forKeyPath: "textColor") }

    /// `ProducerProxy` that refers to read-write property `UITextField.font`
    var font: ProducerProxy<UIFont, Void> { return updatable(forKeyPath: "font", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UITextField.textAlignment`
    var textAlignment: ProducerProxy<NSTextAlignment, Void> {
      return updatable(forKeyPath: "textAlignment", onNone: .drop,
                       customGetter: { $0.textAlignment },
                       customSetter: { $0.textAlignment = $1 })
    }

    /// `ProducerProxy` that refers to read-write property `UITextField.placeholder`
    var placeholder: ProducerProxy<String?, Void> { return updatable(forKeyPath: "placeholder") }

    /// `ProducerProxy` that refers to read-write property `UITextField.attributedPlaceholder`
    var attributedPlaceholder: ProducerProxy<NSAttributedString?, Void> {
      return updatable(forKeyPath: "attributedPlaceholder")
    }

    /// `ProducerProxy` that refers to read-write property `UITextField.background`
    var background: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "background") }

    /// `ProducerProxy` that refers to read-write property `UITextField.disabledBackground`
    var disabledBackground: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "disabledBackground") }

    /// `Channel` that refers to read-only property `UITextField.isEditing`
    var isEditing: Channel<Bool, Void> { return updating(forKeyPath: "isEditing", onNone: .drop) }
  }

  // MARK: - reactive properties for UITextView
  public extension ReactiveProperties where Object: UITextView {
    /// `ProducerProxy` that refers to read-write property `UITextView.text`
    var text: ProducerProxy<String, Void> { return updatable(forKeyPath: "text", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UITextView.font`
    var font: ProducerProxy<UIFont, Void> { return updatable(forKeyPath: "font", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UITextView.textColor`
    var textColor: ProducerProxy<UIColor?, Void> { return updatable(forKeyPath: "textColor") }

    /// `ProducerProxy` that refers to read-write property `UITextView.textAlignment`
    var textAlignment: ProducerProxy<NSTextAlignment, Void> {
      return updatable(forKeyPath: "textAlignment",
                       onNone: .drop,
                       customGetter: { $0.textAlignment },
                       customSetter: { $0.textAlignment = $1 })
    }

    /// `ProducerProxy` that refers to read-write property `UITextView.isEditable`
    var isEditable: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "editable", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UITextView.isSelectable`
    var isSelectable: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "selectable", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UITextView.attributedText`
    var attributedText: ProducerProxy<NSAttributedString, Void> {
      return updatable(forKeyPath: "attributedText", onNone: .drop)
    }

    /// `ProducerProxy` that refers to read-write property `UITextView.clearsOnInsertion`
    var clearsOnInsertion: ProducerProxy<Bool, Void> {
      return updatable(forKeyPath: "clearsOnInsertion", onNone: .drop)
    }
  }

  // MARK: - reactive properties for UISearchBar
  public extension ReactiveProperties where Object: UISearchBar {

#if os(iOS)
    /// `ProducerProxy` that refers to read-write property `UISearchBar.barStyle`
    var barStyle: ProducerProxy<UIBarStyle, Void> {
      return updatable(forKeyPath: "barStyle",
                       onNone: .drop,
                       customGetter: { $0.barStyle },
                       customSetter: { $0.barStyle = $1 })
    }
#endif

    /// `ProducerProxy` that refers to read-write property `UISearchBar.text`
    var text: ProducerProxy<String, Void> { return updatable(forKeyPath: "text", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UISearchBar.prompt`
    var prompt: ProducerProxy<String?, Void> { return updatable(forKeyPath: "prompt") }

    /// `ProducerProxy` that refers to read-write property `UISearchBar.placeholder`
    var placeholder: ProducerProxy<String?, Void> { return updatable(forKeyPath: "placeholder") }

    /// `ProducerProxy` that refers to read-write property `UISearchBar.showsBookmarkButton`
    var showsBookmarkButton: ProducerProxy<Bool, Void> {
      return updatable(forKeyPath: "showsBookmarkButton", onNone: .drop)
    }

    /// `ProducerProxy` that refers to read-write property `UISearchBar.showsCancelButton`
    var showsCancelButton: ProducerProxy<Bool, Void> {
      return updatable(forKeyPath: "showsCancelButton", onNone: .drop)
    }

    /// `ProducerProxy` that refers to read-write property `UISearchBar.showsSearchResultsButton`
    var showsSearchResultsButton: ProducerProxy<Bool, Void> {
      return updatable(forKeyPath: "showsSearchResultsButton", onNone: .drop)
    }

    /// `ProducerProxy` that refers to read-write property `UISearchBar.isSearchResultsButtonSelected`
    var isSearchResultsButtonSelected: ProducerProxy<Bool, Void> {
      return updatable(forKeyPath: "searchResultsButtonSelected", onNone: .drop)
    }

    /// `ProducerProxy` that refers to read-write property `UISearchBar.barTintColor`
    var barTintColor: ProducerProxy<UIColor, Void> { return updatable(forKeyPath: "barTintColor", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UISearchBar.searchBarStyle`
    var searchBarStyle: ProducerProxy<UISearchBarStyle, Void> {
      return updatable(forKeyPath: "searchBarStyle",
                       onNone: .drop,
                       customGetter: { $0.searchBarStyle },
                       customSetter: { $0.searchBarStyle = $1 })
    }
  }

  // MARK: - reactive properties for UIImageView
  public extension ReactiveProperties where Object: UIImageView {
    /// `ProducerProxy` that refers to read-write property `UIImageView.image`
    var image: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "image") }

    /// `ProducerProxy` that refers to read-write property `UIImageView.highlightedImage`
    var highlightedImage: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "highlightedImage") }

    /// `ProducerProxy` that refers to read-write property `UIImageView.isHighlighted`
    var isHighlighted: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "highlighted", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIImageView.animationImages`
    var animationImages: ProducerProxy<[UIImage]?, Void> { return updatable(forKeyPath: "animationImages") }

    /// `ProducerProxy` that refers to read-write property `UIImageView.highlightedAnimationImages`
    var highlightedAnimationImages: ProducerProxy<[UIImage]?, Void> {
      return updatable(forKeyPath: "highlightedAnimationImages")
    }

    /// `ProducerProxy` that refers to read-write property `UIImageView.animationDuration`
    var animationDuration: ProducerProxy<TimeInterval, Void> {
      return updatable(forKeyPath: "animationDuration", onNone: .drop)
    }

    /// `ProducerProxy` that refers to read-write property `UIImageView.animationRepeatCount`
    var animationRepeatCount: ProducerProxy<Int, Void> {
      return updatable(forKeyPath: "animationRepeatCount", onNone: .drop)
    }

    /// `ProducerProxy` that refers to read-write property `UIImageView.isAnimating`
    var isAnimating: ProducerProxy<Bool, Void> {
      return updatable(forKeyPath: "animating",
                       onNone: .drop,
                       customGetter: { $0.isAnimating },
                       customSetter: {
          if $1 {
            $0.startAnimating()
          } else {
            $0.stopAnimating()
          }
      })
    }
  }

  // MARK: - reactive properties for UIButton
  public extension ReactiveProperties where Object: UIButton {

    /// `Sink` that refers to write-only `UIImageView.setTitle(_:, for:)`
    func title(for state: UIControlState) -> Sink<String?, Void> {
      return sink { $0.setTitle($1, for: state) }
    }

    /// `Sink` that refers to write-only `UIImageView.setTitleShadowColor(_:, for:)`
    func titleShadowColor(for state: UIControlState) -> Sink<UIColor?, Void> {
      return sink { $0.setTitleShadowColor($1, for: state) }
    }

    /// `Sink` that refers to write-only `UIImageView.setImage(_:, for:)`
    func image(for state: UIControlState) -> Sink<UIImage?, Void> {
      return sink { $0.setImage($1, for: state) }
    }

    /// `Sink` that refers to write-only `UIImageView.setBackgroundImage(_:, for:)`
    func backgroundImage(for state: UIControlState) -> Sink<UIImage?, Void> {
      return sink { $0.setBackgroundImage($1, for: state) }
    }

    /// `Sink` that refers to write-only `UIImageView.setAttributedTitle(_:, for:)`
    func attributedTitle(for state: UIControlState) -> Sink<NSAttributedString?, Void> {
      return sink { $0.setAttributedTitle($1, for: state) }
    }
  }

  extension UIBarItem: ObjCUIInjectedExecutionContext {}

  // MARK: - reactive properties for UIBarItem
  public extension ReactiveProperties where Object: UIBarItem {
    /// `ProducerProxy` that refers to read-write property `UIBarItem.title`
    var isEnabled: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "enabled", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIBarItem.title`
    var title: ProducerProxy<String?, Void> { return updatable(forKeyPath: "title") }

    /// `ProducerProxy` that refers to read-write property `UIBarItem.image`
    var image: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "image") }

    /// `ProducerProxy` that refers to read-write property `UIBarItem.landscapeImagePhone`
    @available(iOS 8.0, *)
    var landscapeImagePhone: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "landscapeImagePhone") }

    #if swift(>=4.0)
    /// `Sink` that refers to write-only `UIBarItem.setTitleTextAttributes(_:, for:)`
    func titleTextAttributes(for state: UIControlState) -> Sink<[NSAttributedStringKey: Any]?, Void> {
      return sink { $0.setTitleTextAttributes($1, for: state) }
    }
    #else
    /// `Sink` that refers to write-only `UIBarItem.setTitleTextAttributes(_:, for:)`
    func titleTextAttributes(for state: UIControlState) -> Sink<[String: Any]?, Void> {
      return sink { $0.setTitleTextAttributes($1, for: state) }
    }
    #endif
  }

  // MARK: - reactive properties for UIBarButtonItem
  public extension ReactiveProperties where Object: UIBarButtonItem {

    /// Makes or returns cached channel. The channel that will have update on each triggering of action
    func actionChannel() -> Channel<AnyObject?, Void> {
      if let actionReceiver = object.target as? UIBarButtonItemActionReceiver {
        return actionReceiver.producer
      } else {
        let actionReceiver = UIBarButtonItemActionReceiver(object: object)
        object.target = actionReceiver
        object.action = #selector(UIBarButtonItemActionReceiver.asyncNinjaAction(sender:))
        object.notifyDeinit {
          actionReceiver.producer.cancelBecauseOfDeallocatedContext(from: nil)
        }
        return actionReceiver.producer
      }
    }

    /// `ProducerProxy` that refers to read-write property `UIBarButtonItem.style`
    var style: ProducerProxy<UIBarButtonItemStyle, Void> {
      return updatable(forKeyPath: "style", onNone: .drop, customGetter: { $0.style }, customSetter: { $0.style = $1 })
    }

    /// `ProducerProxy` that refers to read-write property `UIBarButtonItem.width`
    var width: ProducerProxy<CGFloat, Void> {
      return updatable(forKeyPath: "width", onNone: .drop)
    }

    /// `ProducerProxy` that refers to read-write property `UIBarButtonItem.width`
    var possibleTitles: ProducerProxy<Set<String>?, Void> {
      return updatable(forKeyPath: "possibleTitles",
                       customGetter: { $0.possibleTitles },
                       customSetter: { $0.possibleTitles = $1 })
    }

    /// `Sink` that refers to write-only `UIBarButtonItem.setBackgroundImage(_:, for:, barMetrics:)`
    func backgroundImage(for state: UIControlState, barMetrics: UIBarMetrics) -> Sink<UIImage?, Void> {
      return sink { $0.setBackgroundImage($1, for: state, barMetrics: barMetrics) }
    }

    /// `Sink` that refers to write-only `UIBarButtonItem.setBackgroundImage(_:, for:, style:, barMetrics:)`
    func backgroundImage(
      for state: UIControlState,
      style: UIBarButtonItemStyle,
      barMetrics: UIBarMetrics
      ) -> Sink<UIImage?, Void> {
      return sink { $0.setBackgroundImage($1, for: state, style: style, barMetrics: barMetrics) }
    }

    /// `ProducerProxy` that refers to read-write property `UIBarButtonItem.tintColor`
    var tintColor: ProducerProxy<UIColor?, Void> {
      return updatable(forKeyPath: "tintColor",
                       customGetter: { $0.tintColor },
                       customSetter: { $0.tintColor = $1 })
    }

    /// `Sink` that refers to write-only `UIBarButtonItem.setBackgroundVerticalPositionAdjustment(_:, for:)`
    func backgroundVerticalPositionAdjustment(for barMetrics: UIBarMetrics) -> Sink<CGFloat, Void> {
      return sink { $0.setBackgroundVerticalPositionAdjustment($1, for: barMetrics) }
    }

    /// `Sink` that refers to write-only `UIBarButtonItem.setTitlePositionAdjustment(_:, for:)`
    func titlePositionAdjustment(for barMetrics: UIBarMetrics) -> Sink<UIOffset, Void> {
      return sink { $0.setTitlePositionAdjustment($1, for: barMetrics) }
    }

    #if os(iOS)
    /// `Sink` that refers to write-only `UIBarButtonItem.setBackButtonBackgroundImage(_:, for:, barMetrics:)`
    func backButtonBackgroundImage(for state: UIControlState, barMetrics: UIBarMetrics) -> Sink<UIImage?, Void> {
      return sink { $0.setBackButtonBackgroundImage($1, for: state, barMetrics: barMetrics) }
    }

    /// `Sink` that refers to write-only `UIBarButtonItem.setBackButtonTitlePositionAdjustment(_:, for:)`
    func backButtonTitlePositionAdjustment(for barMetrics: UIBarMetrics) -> Sink<UIOffset, Void> {
      return sink { $0.setBackButtonTitlePositionAdjustment($1, for: barMetrics) }
    }

    /// `Sink` that refers to write-only
    /// `UIBarButtonItem.setBackButtonBackgroundVerticalPositionAdjustment(_:, for:)`
    func backButtonBackgroundVerticalPositionAdjustment(for barMetrics: UIBarMetrics) -> Sink<CGFloat, Void> {
      return sink { $0.setBackButtonBackgroundVerticalPositionAdjustment($1, for: barMetrics) }
    }
    #endif
  }

  private class UIBarButtonItemActionReceiver: NSObject {
    weak var object: UIBarButtonItem?
    let producer = Producer<AnyObject?, Void>(bufferSize: 0)

    init(object: UIBarButtonItem) {
      self.object = object
    }

    @objc dynamic func asyncNinjaAction(sender: AnyObject?) {
      self.producer.update(sender, from: .main)
    }
  }

#if os(iOS)
  // MARK: - reactive properties for UIDatePicker
  public extension ReactiveProperties where Object: UIDatePicker {
    /// `ProducerProxy` that refers to read-write property `UIDatePicker.datePickerMode`
    var datePickerMode: ProducerProxy<UIDatePickerMode, Void> {
      return updatable(forKeyPath: "datePickerMode",
                       onNone: .drop,
                       customGetter: { $0.datePickerMode },
                       customSetter: { $0.datePickerMode = $1 })
    }

    /// `ProducerProxy` that refers to read-write property `UIDatePicker.locale`
    var locale: ProducerProxy<Locale, Void> { return updatable(forKeyPath: "locale", onNone: .replace(Locale.current)) }

    /// `ProducerProxy` that refers to read-write property `UIDatePicker.calendar`
    var calendar: ProducerProxy<Calendar, Void> {
      return updatable(forKeyPath: "calendar", onNone: .replace(Calendar.current))
    }

    /// `ProducerProxy` that refers to read-write property `UIDatePicker.timeZone`
    var timeZone: ProducerProxy<TimeZone?, Void> { return updatable(forKeyPath: "timeZone") }

    /// `ProducerProxy` that refers to read-write property `UIDatePicker.date`
    var date: ProducerProxy<Date, Void> { return updatable(forKeyPath: "date", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIDatePicker.dateWithAnimation`
    var dateWithAnimation: ProducerProxy<(date: Date, isAnimated: Bool), Void> {
      return updatable(forKeyPath: "date", onNone: .drop,
                       customGetter: { (date: $0.date, isAnimated: false) },
                       customSetter: { $0.setDate($1.date, animated: $1.isAnimated) })
    }

    /// `ProducerProxy` that refers to read-write property `UIDatePicker.minimumDate`
    var minimumDate: Sink<Date?, Void> { return sink { $0.minimumDate = $1 } }

    /// `ProducerProxy` that refers to read-write property `UIDatePicker.maximumDate`
    var maximumDate: Sink<Date?, Void> { return sink { $0.maximumDate = $1 } }

    //    TODO: Investigate
    //    /// `ProducerProxy` that refers to read-write property `UIDatePicker.countDownDuration`
    //    var countDownDuration: ProducerProxy<TimeInterval, Void> {
    //      return updatable(forKeyPath: "countDownDuration", onNone: .drop)
    //    }

    /// `ProducerProxy` that refers to read-write property `UIDatePicker.minuteInterval`
    var minuteInterval: ProducerProxy<Int, Void> { return updatable(forKeyPath: "minuteInterval", onNone: .drop) }
  }

  // MARK: - reactive properties for UISwitch
  public extension ReactiveProperties where Object: UISwitch {
    /// `ProducerProxy` that refers to read-write property `UISwitch.isOn`
    var isOn: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "on", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UISwitch.isOnWithAnimation`
    var isOnWithAnimation: ProducerProxy<(isOn: Bool, isAnimated: Bool), Void> {
      return updatable(forKeyPath: "on", onNone: .drop,
                       customGetter: { return (isOn: $0.isOn, isAnimated: false) },
                       customSetter: { $0.setOn($1.isOn, animated: $1.isAnimated) })
    }

    /// `ProducerProxy` that refers to read-write property `UISwitch.onTintColor`
    var onTintColor: ProducerProxy<UIColor?, Void> { return updatable(forKeyPath: "onTintColor") }

    /// `ProducerProxy` that refers to read-write property `UISwitch.thumbTintColor`
    var thumbTintColor: ProducerProxy<UIColor?, Void> { return updatable(forKeyPath: "thumbTintColor") }

    /// `ProducerProxy` that refers to read-write property `UISwitch.onImage`
    var onImage: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "onImage") }

    /// `ProducerProxy` that refers to read-write property `UISwitch.offImage`
    var offImage: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "offImage") }
  }

  // MARK: - reactive properties for UIStepper
  public extension ReactiveProperties where Object: UIStepper {
    /// `ProducerProxy` that refers to read-write property `UIStepper.isContinuous`
    var isContinuous: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "continuous", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIStepper.autorepeat`
    var autorepeat: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "autorepeat", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIStepper.wraps`
    var wraps: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "wraps", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIStepper.value`
    var value: ProducerProxy<Double, Void> { return updatable(forKeyPath: "value", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIStepper.minimumValue`
    var minimumValue: ProducerProxy<Double, Void> { return updatable(forKeyPath: "minimumValue", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIStepper.maximumValue`
    var maximumValue: ProducerProxy<Double, Void> { return updatable(forKeyPath: "maximumValue", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UIStepper.stepValue`
    var stepValue: ProducerProxy<Double, Void> { return updatable(forKeyPath: "stepValue", onNone: .drop) }

    /// `Sink` that refers to write-only `UIStepper.setBackButtonBackgroundImage(_:, for:)`
    func backgroundImage(for state: UIControlState) -> Sink<UIImage?, Void> {
      return sink { $0.setBackgroundImage($1, for: state) }
    }

    /// `Sink` that refers to write-only `UIStepper.setDividerImage(_:, forLeftSegmentState:, rightSegmentState:)`
    func dividerImage(
      forLeftSegmentState leftState: UIControlState,
      rightSegmentState rightState: UIControlState
      ) -> Sink<UIImage?, Void> {
      return sink { $0.setDividerImage($1, forLeftSegmentState: leftState, rightSegmentState: rightState) }
    }

    /// `Sink` that refers to write-only `setIncrementImage(_:, for:)`
    func incrementImage(for state: UIControlState) -> Sink<UIImage?, Void> {
      return sink { $0.setIncrementImage($1, for: state) }
    }

    /// `Sink` that refers to write-only `setDecrementImage(_:, for:)`
    func decrementImage(for state: UIControlState) -> Sink<UIImage?, Void> {
      return sink { $0.setDecrementImage($1, for: state) }
    }
  }

  // MARK: - reactive properties for UISlider
  public extension ReactiveProperties where Object: UISlider {
    /// `ProducerProxy` that refers to read-write property `UISlider.value`
    var value: ProducerProxy<Float, Void> { return updatable(forKeyPath: "value", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UISlider.minimumValue`
    var minimumValue: ProducerProxy<Float, Void> { return updatable(forKeyPath: "minimumValue", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UISlider.maximumValue`
    var maximumValue: ProducerProxy<Float, Void> { return updatable(forKeyPath: "maximumValue", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UISlider.minimumValueImage`
    var minimumValueImage: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "minimumValueImage") }

    /// `ProducerProxy` that refers to read-write property `UISlider.maximumValueImage`
    var maximumValueImage: ProducerProxy<UIImage?, Void> { return updatable(forKeyPath: "maximumValueImage") }

    /// `ProducerProxy` that refers to read-write property `UIStepper.isContinuous`
    var isContinuous: ProducerProxy<Bool, Void> { return updatable(forKeyPath: "continuous", onNone: .drop) }

    /// `ProducerProxy` that refers to read-write property `UISlider.minimumTrackTintColor`
    var minimumTrackTintColor: ProducerProxy<UIColor?, Void> { return updatable(forKeyPath: "minimumTrackTintColor") }

    /// `ProducerProxy` that refers to read-write property `UISlider.maximumTrackTintColor`
    var maximumTrackTintColor: ProducerProxy<UIColor?, Void> { return updatable(forKeyPath: "maximumTrackTintColor") }

    /// `ProducerProxy` that refers to read-write property `UISlider.thumbTintColor`
    var thumbTintColor: ProducerProxy<UIColor?, Void> { return updatable(forKeyPath: "thumbTintColor") }

    /// `ProducerProxy` that refers to read-write property `UISlider.valueWithAnimation`
    var valueWithAnimation: ProducerProxy<(value: Float, isAnimated: Bool), Void> {
      return updatable(forKeyPath: "value", onNone: .drop,
                       customGetter: { (value: $0.value, isAnimated: false) },
                       customSetter: { $0.setValue($1.value, animated: $1.isAnimated) })
    }

    /// `Sink` that refers to write-only `UISlider.setThumbImage(_:, for:)`
    func thumbImage(for state: UIControlState) -> Sink<UIImage?, Void> {
      return sink { $0.setThumbImage($1, for: state) }
    }

    /// `Sink` that refers to write-only `UISlider.setMinimumTrackImage(_:, for:)`
    func minimumTrackImage(for state: UIControlState) -> Sink<UIImage?, Void> {
      return sink { $0.setMinimumTrackImage($1, for: state) }
    }

    /// `Sink` that refers to write-only `UISlider.setMaximumTrackImage(_:, for:)`
    func maximumTrackImage(for state: UIControlState) -> Sink<UIImage?, Void> {
      return sink { $0.setMaximumTrackImage($1, for: state) }
    }
  }
#endif

  // MARK: - reactive properties for UIViewController
  public extension ReactiveProperties where Object: UIViewController {
    /// `UpdatableProperty` that refers to read-write property `UIViewController.title`
    var title: ProducerProxy<String?, Void> { return updatable(forKeyPath: "title") }
  }

  // MARK: - UIGestureRecognizer
  extension UIGestureRecognizer: ObjCUIInjectedExecutionContext { }

  // MARK: - reactive properties for UIGestureRecognizer
  public extension ReactiveProperties where Object: UIGestureRecognizer {
    /// Makes channel that will have update value on each triggering of action
    ///
    /// - Parameter events: events that to listen for
    /// - Returns: unbuffered channel
    var actions: Channel<UIGestureRecognizer, Void> {
      let actionReceiver = UIGestureRecognizerActionReceiver(object: object)
      object.addTarget(actionReceiver,
                     action: #selector(UIGestureRecognizerActionReceiver.asyncNinjaAction(gestureRecogniser:)))
      object.notifyDeinit {
        actionReceiver.producer.cancelBecauseOfDeallocatedContext(from: nil)
      }

      return actionReceiver.producer
    }
  }

  class UIGestureRecognizerActionReceiver: NSObject {
    weak var object: UIGestureRecognizer?
    let producer = Producer<UIGestureRecognizer, Void>(bufferSize: 0)

    init(object: UIGestureRecognizer) {
      self.object = object
    }

    @objc dynamic func asyncNinjaAction(gestureRecogniser: UIGestureRecognizer) {
      self.producer.update(gestureRecogniser, from: .main)
    }
  }

  // MARK: - UIDevice
  extension UIDevice: ObjCUIInjectedExecutionContext {}

  // MARK: - reactive properties for UIDevice
  public extension ReactiveProperties where Object: UIDevice {

    #if os(iOS)

    /// `Channel` that refers to read-only property `UIControl.state`
    var orientation: Channel<UIDeviceOrientation, Void> {
      let simulatedEventsProducer = Producer<UIDeviceOrientation, Void>(bufferedUpdates: [.unknown])
      let notificationsChannel: Channel<Notification, Void> = NotificationCenter.default
        .updatable(
          object: UIDevice.current,
          name: .UIDeviceOrientationDidChange,
          observationSession: observationSession
        ) { [weak simulatedEventsProducer] (_, object, isEnabled) in
          if isEnabled {
            object.beginGeneratingDeviceOrientationNotifications()
            simulatedEventsProducer?.update(object.orientation)
          } else {
            object.endGeneratingDeviceOrientationNotifications()
            simulatedEventsProducer?.update(.unknown)
          }
      }
      let realEventsProducer = notificationsChannel
        .map(executor: .immediate) { ($0.object as! UIDevice).orientation }
      return merge(simulatedEventsProducer, realEventsProducer)
        .mapSuccess { _ in return () }
    }

    #endif
  }
#endif
