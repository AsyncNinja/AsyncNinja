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

  /// A policy for handling `None` (or `nil`) update of `Channel<Update?, Success>`
  public enum UpdateWithNoneHandlingPolicy<T> {

    /// drop `None` (or `nil`) update
    case drop

    /// replace `None` (or `nil`) with a specified value
    case replace(T)
  }

/// **Internal use only** `KeyPathObserver` is an object for managing KVO.
final class KeyPathObserver<Root: NSObject, Value>: ObservationSessionItem {
  typealias _KeyPath = KeyPath<Root, Value>
  typealias _ChangeHandler = (Root, NSKeyValueObservedChange<Value>) -> Void

  let _keyPath: _KeyPath
  private weak var _object: Root?
  private let _changeHandler: _ChangeHandler
  private var _observation: NSKeyValueObservation?
  private let _options: NSKeyValueObservingOptions

  var isEnabled: Bool {
    get { return _observation.isSome }
    set {
      if newValue == _observation.isSome {
        // do nothing
      } else if !newValue {
        _observation = .none
      } else if _observation.isNone {
        _observation = _object?.observe(_keyPath, options: _options, changeHandler: _changeHandler)
      }
    }
  }

  init(keyPath: _KeyPath, object: Root, options: NSKeyValueObservingOptions, changeHandler: @escaping _ChangeHandler) {
    _keyPath = keyPath
    _object = object
    _options = options
    _changeHandler = changeHandler
    _observation = .none
    isEnabled = true
  }
}

  @objc protocol ObservationSessionItem: AnyObject {
    var isEnabled: Bool { get set }
  }

  /// An object that is able to control (enable and disable) observation-related channel constructors
  public class ObservationSession {

    /// enables or disables observation
    public var isEnabled: Bool {
      didSet {
        if isEnabled != oldValue {
          for item in items {
            item?.isEnabled = isEnabled
          }
        }
      }
    }

    private var items = QueueOfWeakElements<ObservationSessionItem>()

    /// designated initializer
    public init(isEnabled: Bool = true) {
      self.isEnabled = isEnabled
    }

    func insert(item: ObservationSessionItem) {
      items.push(item)
    }
  }
#endif
