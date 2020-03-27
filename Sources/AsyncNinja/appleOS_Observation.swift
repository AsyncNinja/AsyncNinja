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
    /// block that is called as new events being observed
    typealias ObservationBlock = (_ object: Any?, _ changes: [NSKeyValueChangeKey: Any]) -> Void

    let object: Unmanaged<NSObject>
    let keyPath: String
    let options: NSKeyValueObservingOptions
    let observationBlock: ObservationBlock
    var isEnabled: Bool {
      didSet {
        if isEnabled == oldValue {
          return
        } else if isEnabled {
          object.takeUnretainedValue().addObserver(self, forKeyPath: keyPath, options: options, context: nil)
        } else {
          object.takeUnretainedValue().removeObserver(self, forKeyPath: keyPath)
        }
      }
    }

    init(object: NSObject,
         keyPath: String,
         options: NSKeyValueObservingOptions,
         isEnabled: Bool,
         observationBlock: @escaping ObservationBlock) {
      self.object = Unmanaged.passUnretained(object)
      self.keyPath = keyPath
      self.options = options
      self.observationBlock = observationBlock
      self.isEnabled = isEnabled
      super.init()
      if isEnabled {
        object.addObserver(self, forKeyPath: keyPath, options: options, context: nil)
      }
    }

    deinit {
      self.isEnabled = false
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey: Any]?,
                               context: UnsafeMutableRawPointer?) {
      assert(keyPath == self.keyPath)
      if let change = change {
        observationBlock(object, change)
      }
    }
  }

  @objc public protocol ObservationSessionItem: AnyObject {
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
