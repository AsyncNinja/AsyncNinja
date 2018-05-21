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
final class KeyPathObserver: NSObject, ObservationSessionItem {
  typealias _ChangeHandler = () -> Void

  let _keyPath: String
  private weak var _object: NSObject?
  private let _changeHandler: _ChangeHandler
  private var _isEnabled: Bool = false

  var isEnabled: Bool {
    get { return _isEnabled }
    set {
      if newValue == _isEnabled {
        // do nothing
      } else if newValue {
        _object?.addObserver(self, forKeyPath: _keyPath, options: [.initial], context: nil)
        _isEnabled = true
      } else {
        _object?.removeObserver(self, forKeyPath: _keyPath)
        _isEnabled = false
      }
    }
  }

  init(kvcKeyPath: String, object: NSObject, changeHandler: @escaping _ChangeHandler) {
    _keyPath = kvcKeyPath
    _object = object
    _changeHandler = changeHandler
    super.init()
    isEnabled = true
  }

  convenience init?(keyPath: AnyKeyPath, object: NSObject, changeHandler: @escaping _ChangeHandler) {
    guard let kvcKeyPath = keyPath._kvcKeyPathString else { return nil }
    self.init(kvcKeyPath: kvcKeyPath, object: object, changeHandler: changeHandler)
  }

  override func observeValue(forKeyPath keyPath: String?,
                             of object: Any?,
                             change: [NSKeyValueChangeKey : Any]?,
                             context: UnsafeMutableRawPointer?) {
    _changeHandler()
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
