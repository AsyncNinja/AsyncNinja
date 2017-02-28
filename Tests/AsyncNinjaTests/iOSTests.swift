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
  import XCTest
  import Dispatch
  import UIKit
  @testable import AsyncNinja

  class iOSTests: XCTestCase {
    static let allTests = [
      ("testUIView", testUIView),
      ("testUIControl", testUIControl),
      ("testUITextField", testUITextField),
      ("testUIViewController", testUIViewController),
      ]

    static let cgFloatFixture: [CGFloat] = [0.0, 0.0, 0.25, 0.5, 0.5, 1.0, 1.0]
    static let boolFixture: [Bool] = [true, true, false, false, true]
    static let stringsAndNilsFixture: [String?] = ["1", nil, "1", "1", "2", "2", nil, nil, "3", "1", "4"]
    static let stringsFixture: [String] = stringsAndNilsFixture.flatMap { $0 }
    static let colorsFiture: [UIColor] = [.white, .white, .red, .green, .green, .blue, .blue]
    static let fontTextStyleFixture: [UIFontTextStyle] = [.headline, .subheadline, .body, .footnote, .caption1, .caption2]
    static let fontsFiture: [UIFont] = iOSTests.fontTextStyleFixture
      .map(UIFont.preferredFont(forTextStyle:))
    static let textAlignementFixture: [NSTextAlignment] = [.center, .left, .left, .center, .right, .right, .natural, .natural]
    
    static func drawTestImage(_ text: String) -> UIImage {
      return UIImage.draw(size: CGSize(width: 100, height: 100)) { _ in
        text.draw(at: CGPoint(x: 0, y: 0), withAttributes: [:])
      }
    }
    
    static let imageOne = drawTestImage("1")
    static let imageTwo = drawTestImage("2")
    static let imageThree = drawTestImage("3")
    static let imageFour = drawTestImage("4")
    static let imagesAndNilsFixture: [UIImage?] = [imageOne, nil, imageOne,
                                                   imageOne, imageTwo, imageTwo,
                                                   nil, nil, imageThree,
                                                   imageOne, imageFour]

    func testUIView() {
      let object = UIView()
      self.testUpdatableProperty(updatable: object.rp.alpha,
                                 object: object,
                                 keyPath: "alpha",
                                 values: iOSTests.cgFloatFixture)
      self.testUpdatableProperty(updatable: object.rp.isHidden,
                                 object: object,
                                 keyPath: "hidden",
                                 values: iOSTests.boolFixture)
      self.testUpdatableProperty(updatable: object.rp.isOpaque,
                                 object: object,
                                 keyPath: "opaque",
                                 values: iOSTests.boolFixture)
      self.testUpdatableProperty(updatable: object.rp.isUserInteractionEnabled,
                                 object: object,
                                 keyPath: "userInteractionEnabled",
                                 values: iOSTests.boolFixture)
    }

    func testUIControl() {
      let object = UIControl()
      self.testUpdatableProperty(updatable: object.rp.isEnabled,
                                 object: object,
                                 keyPath: "enabled",
                                 values: iOSTests.boolFixture)
      self.testUpdatableProperty(updatable: object.rp.isSelected,
                                 object: object,
                                 keyPath: "selected",
                                 values: iOSTests.boolFixture)
    }

    func testUITextField() {
      let object = UITextField()
      let attributedStringsFixture = iOSTests.stringsFixture
        .map { NSAttributedString(string: $0, attributes: object.defaultTextAttributes) }
      self.testUpdatableProperty(updatable: object.rp.text,
                                 object: object,
                                 keyPath: "text",
                                 values: iOSTests.stringsFixture)
      self.testUpdatableProperty(updatable: object.rp.attributedText,
                                 object: object,
                                 keyPath: "attributedText",
                                 values: attributedStringsFixture)
      self.testUpdatableProperty(updatable: object.rp.textColor,
                                 object: object,
                                 keyPath: "textColor",
                                 values: iOSTests.colorsFiture)
      self.testUpdatableProperty(updatable: object.rp.font,
                                 object: object,
                                 keyPath: "font",
                                 values: iOSTests.fontsFiture)
      self.testUpdatableProperty(updatable: object.rp.textAlignment,
                                 object: object,
                                 keyPath: "textAlignment",
                                 values: iOSTests.textAlignementFixture,
                                 customGetter: { $0.textAlignment },
                                 customSetter: { $0.textAlignment = $1! })
      self.testUpdatableProperty(updatable: object.rp.placeholder,
                                 object: object,
                                 keyPath: "placeholder",
                                 values: iOSTests.stringsFixture)
      self.testUpdatableProperty(updatable: object.rp.attributedPlaceholder,
                                 object: object,
                                 keyPath: "attributedPlaceholder",
                                 values: attributedStringsFixture)
      self.testUpdatableProperty(updatable: object.rp.background,
                                 object: object,
                                 keyPath: "background",
                                 values: iOSTests.imagesAndNilsFixture)
      self.testUpdatableProperty(updatable: object.rp.disabledBackground,
                                 object: object,
                                 keyPath: "disabledBackground",
                                 values: iOSTests.imagesAndNilsFixture)
    }

    func testUIViewController() {
      let object = UIViewController()
      self.testUpdatableProperty(updatable: object.rp.title,
                                 object: object,
                                 keyPath: "title",
                                 values: iOSTests.stringsAndNilsFixture)
    }
    
    private func testUpdatableProperty<T: Equatable, Object: NSObject>(
      updatable: UpdatableProperty<T>,
      object: Object,
      keyPath: String,
      values: [T],
      file: StaticString = #file,
      line: UInt = #line,
      customGetter: ((Object) -> T?)? = nil,
      customSetter: ((Object, T?) -> Void)? = nil)
    {
      for value in values {
        updatable.update(value, from: .main)
        let objectValue: T?
        if let customGetter = customGetter {
          objectValue = customGetter(object)
        } else {
          objectValue = object.value(forKeyPath: keyPath) as? T
        }
        XCTAssertEqual(objectValue, value)
      }
      self.testUpdating(updating: updatable, object: object, keyPath: keyPath, values: values, file: file, line: line, customSetter: customSetter)
    }
    
    private func testUpdating<T: Equatable, Object: NSObject>(
      updating: Updating<T>,
      object: Object,
      keyPath: String,
      values: [T],
      file: StaticString = #file,
      line: UInt = #line,
      customSetter: ((Object, T?) -> Void)? = nil)
    {
      var updatingIterator = updating.makeIterator()
      let _ = updatingIterator.next() // skip an initial value
      for value in values {
        if let customSetter = customSetter {
          customSetter(object, value)
        } else {
          object.setValue(value, forKeyPath: keyPath)
        }

        XCTAssertEqual(updatingIterator.next(), value)
      }
    }

    private func testUpdatableProperty<T: AsyncNinjaOptionalAdaptor, Object: NSObject>(
      updatable: UpdatableProperty<T>,
      object: Object,
      keyPath: String,
      values: [T],
      file: StaticString = #file,
      line: UInt = #line) where T.AsyncNinjaWrapped: Equatable
    {
      for value in values {
        updatable.update(value, from: .main)
        let valueWeGot = object.value(forKeyPath: keyPath) as? T
        XCTAssertEqual(valueWeGot?.asyncNinjaOptionalValue, value.asyncNinjaOptionalValue)
      }
    }

    private func testUpdating<T: AsyncNinjaOptionalAdaptor, Object: NSObject>(
      updating: Updating<T>,
      object: Object,
      keyPath: String,
      values: [T],
      file: StaticString = #file,
      line: UInt = #line)
      where T.AsyncNinjaWrapped: Equatable
    {
      var updatingIterator = updating.makeIterator()
      let _ = updatingIterator.next() // skip an initial value
      for value in values {
        object.setValue(value, forKeyPath: keyPath)
        XCTAssertEqual(updatingIterator.next()?.asyncNinjaOptionalValue, value.asyncNinjaOptionalValue)
      }
    }
  }

  extension UIImage {
    class func draw(size: CGSize, opaque: Bool = false, scale: CGFloat = 0.0, drawer: (CGContext) -> Void) -> UIImage {
      UIGraphicsBeginImageContextWithOptions(size, opaque, scale);
      defer { UIGraphicsEndImageContext(); }
      drawer(UIGraphicsGetCurrentContext()!)
      return UIGraphicsGetImageFromCurrentImageContext()!
    }
  }
  
#endif
