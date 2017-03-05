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
      ("testUISearchBar", testUISearchBar),
      ("testUIImageView", testUIImageView),
      ("testUIViewController", testUIViewController),
      ]

    static let intFixture: [Int] = [1, 1, 2, 2, 3, 1, 4]
    static let timeIntervalFixture: [TimeInterval] = [0.125, 0.125, 0.25, 0.5, 0.5, 1.0, 1.0]
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
    static let arraysOfImagesAndNilsFixture: [[UIImage]?] = iOSTests.imagesAndNilsFixture
      .map { $0.map { [$0] } }

    func testUIView() {
      let object = UIView()
      testBoth(object.rp.alpha,
               object: object,
               keyPath: "alpha",
               values: iOSTests.cgFloatFixture)
      testBoth(object.rp.tintColor,
               object: object,
               keyPath: "tintColor",
               values: iOSTests.colorsFiture)
      testBoth(object.rp.isHidden,
               object: object,
               keyPath: "hidden",
               values: iOSTests.boolFixture)
      testBoth(object.rp.isOpaque,
               object: object,
               keyPath: "opaque",
               values: iOSTests.boolFixture)
      testBoth(object.rp.isUserInteractionEnabled,
               object: object,
               keyPath: "userInteractionEnabled",
               values: iOSTests.boolFixture)
    }

    func testUIControl() {
      let object = UIControl()
      testBoth(object.rp.isEnabled,
               object: object,
               keyPath: "enabled",
               values: iOSTests.boolFixture)
      testBoth(object.rp.isSelected,
               object: object,
               keyPath: "selected",
               values: iOSTests.boolFixture)
    }

    func testUITextField() {
      let object = UITextField()
      let attributedStringsFixture = iOSTests.stringsFixture
        .map { NSAttributedString(string: $0, attributes: object.defaultTextAttributes) }
      testBoth(object.rp.text,
               object: object,
               keyPath: "text",
               values: iOSTests.stringsFixture)
      testBoth(object.rp.attributedText,
               object: object,
               keyPath: "attributedText",
               values: attributedStringsFixture)
      testBoth(object.rp.textColor,
               object: object,
               keyPath: "textColor",
               values: iOSTests.colorsFiture)
      testBoth(object.rp.font,
               object: object,
               keyPath: "font",
               values: iOSTests.fontsFiture)
      testBoth(object.rp.textAlignment,
               object: object,
               keyPath: "textAlignment",
               values: iOSTests.textAlignementFixture,
               customGetter: { $0.textAlignment },
               customSetter: { $0.textAlignment = $1! })
      testBoth(object.rp.placeholder,
               object: object,
               keyPath: "placeholder",
               values: iOSTests.stringsAndNilsFixture)
      testBoth(object.rp.attributedPlaceholder,
               object: object,
               keyPath: "attributedPlaceholder",
               values: attributedStringsFixture)
      testBoth(object.rp.background,
               object: object,
               keyPath: "background",
               values: iOSTests.imagesAndNilsFixture)
      testBoth(object.rp.disabledBackground,
               object: object,
               keyPath: "disabledBackground",
               values: iOSTests.imagesAndNilsFixture)
    }

    func testUISearchBar() {
      let object = UISearchBar()

      testBoth(object.rp.barStyle,
               object: object,
               keyPath: "barStyle",
               values: [.default, .default, .black, .black, .default, .black],
               customGetter: { $0.barStyle },
               customSetter: { $0.barStyle = $1! })
      testBoth(object.rp.text,
               object: object,
               keyPath: "text",
               values: iOSTests.stringsFixture)
      testBoth(object.rp.prompt,
               object: object,
               keyPath: "prompt",
               values: iOSTests.stringsAndNilsFixture)
      testBoth(object.rp.placeholder,
               object: object,
               keyPath: "placeholder",
               values: iOSTests.stringsAndNilsFixture)
      testBoth(object.rp.showsBookmarkButton,
               object: object,
               keyPath: "showsBookmarkButton",
               values: iOSTests.boolFixture)
      testBoth(object.rp.showsCancelButton,
               object: object,
               keyPath: "showsCancelButton",
               values: iOSTests.boolFixture)
      testBoth(object.rp.showsSearchResultsButton,
               object: object,
               keyPath: "showsSearchResultsButton",
               values: iOSTests.boolFixture)
      testBoth(object.rp.isSearchResultsButtonSelected,
               object: object,
               keyPath: "searchResultsButtonSelected",
               values: iOSTests.boolFixture)
      testBoth(object.rp.barTintColor,
               object: object,
               keyPath: "barTintColor",
               values: iOSTests.colorsFiture)
      testBoth(object.rp.searchBarStyle,
               object: object,
               keyPath: "searchBarStyle",
               values: [.default, .default, .prominent, .minimal, .minimal, .default],
               customGetter: { $0.searchBarStyle },
               customSetter: { $0.searchBarStyle = $1! })
    }

    func testUIImageView() {
      let object = UIImageView()

      testBoth(object.rp.image,
               object: object,
               keyPath: "image",
               values: iOSTests.imagesAndNilsFixture)
      testBoth(object.rp.highlightedImage,
               object: object,
               keyPath: "highlightedImage",
               values: iOSTests.imagesAndNilsFixture)
      testBoth(object.rp.isHighlighted,
               object: object,
               keyPath: "highlighted",
               values: iOSTests.boolFixture)
//      self.testStreamable(updatable: object.rp.animationImages,
//                                 object: object,
//                                 keyPath: "animationImages",
//                                 values: iOSTests.arraysOfImagesAndNilsFixture)
//      self.testStreamable(updatable: object.rp.highlightedAnimationImages,
//                                 object: object,
//                                 keyPath: "highlightedAnimationImages",
//                                 values: iOSTests.arraysOfImagesAndNilsFixture)
      testBoth(object.rp.animationDuration,
               object: object,
               keyPath: "animationDuration",
               values: iOSTests.timeIntervalFixture)
      testBoth(object.rp.animationRepeatCount,
               object: object,
               keyPath: "animationRepeatCount",
               values: iOSTests.intFixture)
//      self.testStreamable(updatable: object.rp.isAnimating,
//                                 object: object,
//                                 keyPath: "animating",
//                                 values: iOSTests.boolFixture,
//                                 customGetter: { $0.isAnimating },
//                                 customSetter:
//        {
//          if let newValue = $1 {
//            if newValue {
//              $0.startAnimating()
//            } else {
//              $0.stopAnimating()
//            }
//          }
//      })
    }

    func testUIViewController() {
      let object = UIViewController()
      testBoth(object.rp.title,
               object: object,
               keyPath: "title",
               values: iOSTests.stringsAndNilsFixture)
    }
  }

  // MARK: - T: Equatable
  extension iOSTests {
    func testBoth<T: Streamable&Streaming, Object: NSObject>(
      _ stream: T,
      object: Object,
      keyPath: String,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line,
      customGetter: ((Object) -> T.Update?)? = nil,
      customSetter: ((Object, T.Update?) -> Void)? = nil
    ) where T.Update: Equatable
    {
      testStreamable(stream, object: object, keyPath: keyPath, values: values,
                     file: file, line: line, customGetter: customGetter)
      testStreaming(stream, object: object, keyPath: keyPath, values: values,
                    file: file, line: line, customSetter: customSetter)
    }

    func testStreamable<T: Streamable, Object: NSObject>(
      _ streamable: T,
      object: Object,
      keyPath: String,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line,
      customGetter: ((Object) -> T.Update?)? = nil
    ) where T.Update: Equatable
    {
      for value in values {
        streamable.update(value, from: .main)
        let objectValue: T.Update?
        if let customGetter = customGetter {
          objectValue = customGetter(object)
        } else {
          objectValue = object.value(forKeyPath: keyPath) as? T.Update
        }
        XCTAssertEqual(objectValue, value, file: file, line: line)
      }
    }

    func testStreaming<T: Streaming, Object: NSObject>(
      _ streaming: T,
      object: Object,
      keyPath: String,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line,
      customSetter: ((Object, T.Update?) -> Void)? = nil
      ) where T.Update: Equatable
    {
      var updatingIterator = streaming.makeIterator()
      let _ = updatingIterator.next() // skip an initial value
      for value in values {
        if let customSetter = customSetter {
          customSetter(object, value)
        } else {
          object.setValue(value, forKeyPath: keyPath)
        }

        XCTAssertEqual(updatingIterator.next() as! T.Update?, value, file: file, line: line)
      }
    }

  }

  // MARK: - T: Optional<Equatable>
  extension iOSTests {
    func testBoth<T: Streamable&Streaming, Object: NSObject>(
      _ stream: T,
      object: Object,
      keyPath: String,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line,
      customGetter: ((Object) -> T.Update?)? = nil,
      customSetter: ((Object, T.Update?) -> Void)? = nil
      ) where T.Update: AsyncNinjaOptionalAdaptor, T.Update.AsyncNinjaWrapped: Equatable
    {
      testStreamable(stream, object: object, keyPath: keyPath, values: values,
                     file: file, line: line, customGetter: customGetter)
      testStreaming(stream, object: object, keyPath: keyPath, values: values,
                    file: file, line: line, customSetter: customSetter)
    }

    func testStreamable<T: Streamable, Object: NSObject>(
      _ streamable: T,
      object: Object,
      keyPath: String,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line,
      customGetter: ((Object) -> T.Update?)? = nil
      ) where T.Update: AsyncNinjaOptionalAdaptor, T.Update.AsyncNinjaWrapped: Equatable
    {
      for value in values {
        streamable.update(value, from: .main)

        let objectValue: T.Update?
        if let customGetter = customGetter {
          objectValue = customGetter(object)
        } else {
          objectValue = object.value(forKeyPath: keyPath) as? T.Update
        }
        XCTAssertEqual(objectValue?.asyncNinjaOptionalValue, value.asyncNinjaOptionalValue, file: file, line: line)
      }
    }

    func testStreaming<T: Streaming, Object: NSObject>(
      _ streaming: T,
      object: Object,
      keyPath: String,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line,
      customSetter: ((Object, T.Update?) -> Void)? = nil
    ) where T.Update: AsyncNinjaOptionalAdaptor, T.Update.AsyncNinjaWrapped: Equatable
    {
      var updatingIterator = streaming.makeIterator()
      let _ = updatingIterator.next() // skip an initial value
      for value in values {
        if let customSetter = customSetter {
          customSetter(object, value)
        } else {
          object.setValue(value.asyncNinjaOptionalValue, forKeyPath: keyPath)
        }

        XCTAssertEqual((updatingIterator.next() as! T.Update?)?.asyncNinjaOptionalValue , value.asyncNinjaOptionalValue, file: file, line: line)
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
