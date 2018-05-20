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

class iOSTests: UITestCase {

  // MARK: - 
  static let allTests = [
    ("testUIView", testUIView),
    ("testUIControl", testUIControl),
    ("testUITextField", testUITextField),
    ("testUITextView", testUITextView),
    ("testUISearchBar", testUISearchBar),
    ("testUIImageView", testUIImageView),
//    ("testUIButton", testUIButton),
//    ("testUIBarItem", testUIBarItem),
    ("testUIDatePicker", testUIDatePicker),
    ("testUILabel", testUILabel),
    ("testUISwitch", testUISwitch),
    ("testUIStepper", testUIStepper),
    ("testUISlider", testUISlider),
    ("testUIViewController", testUIViewController)
  ]

  func testUIView() {
    let object = UIView()
    testEventStream(object, keyPath: \.alpha, values: Fixtures.cgFloats)
    testEventStreamForIUO(object, keyPath: \.tintColor, values: Fixtures.colors.map { $0 })
    testEventStream(object, keyPath: \.isHidden, values: Fixtures.bools)
    testEventStream(object, keyPath: \.isOpaque, values: Fixtures.bools)
    testEventStream(object, keyPath: \.isUserInteractionEnabled, values: Fixtures.bools)
  }

  func testUIControl() {
    let object = UIControl()
    testEventStream(object, keyPath: \.isEnabled, values: Fixtures.bools)
    testEventStream(object, keyPath: \.isSelected, values: Fixtures.bools)
  }

  func testUITextField() {
    let object = UITextField()
    let defaultTextAttributes = Dictionary(uniqueKeysWithValues:
      object.defaultTextAttributes.map { (NSAttributedStringKey($0.key), $0.value) })
    let attributedStringsFixtures = Fixtures.strings
      .map { NSAttributedString(string: $0, attributes: defaultTextAttributes) }
    testEventStream(object, keyPath: \.text, values: Fixtures.strings.map { $0 })
    testEventStream(object, keyPath: \.attributedText, values: attributedStringsFixtures.map { $0 })
    testEventStream(object, keyPath: \.textColor, values: Fixtures.colors.map { $0 })
    testEventStream(object, keyPath: \.font, values: Fixtures.fonts.map { $0 })
    testEventStream(object, keyPath: \.textAlignment, values: Fixtures.textAlignements)
    testEventStream(object, keyPath: \.placeholder, values: Fixtures.stringsAndNils)
    testEventStream(object, keyPath: \.attributedPlaceholder, values: attributedStringsFixtures.map { $0 })
    testEventStream(object, keyPath: \.background, values: Fixtures.imagesAndNils)
    testEventStream(object, keyPath: \.disabledBackground, values: Fixtures.imagesAndNils)
  }

  func testUITextView() {
    let object = UITextView()
    testEventStreamForIUO(object, keyPath: \.text, values: Fixtures.strings.map { $0 })
    testEventStream(object, keyPath: \.textColor, values: Fixtures.colorsAndNils)
    testEventStream(object, keyPath: \.font, values: Fixtures.fonts.map { $0 })
    testEventStream(object, keyPath: \.textAlignment, values: Fixtures.textAlignements)
    testEventStream(object, keyPath: \.isEditable, values: Fixtures.bools)
    testEventStream(object, keyPath: \.isSelectable, values: Fixtures.bools)
    testEventStreamForIUO(object, keyPath: \.attributedText, values: Fixtures.attributedStrings.map { $0 })
    testEventStream(object, keyPath: \.clearsOnInsertion, values: Fixtures.bools)
  }

  func testUISearchBar() {
    #if os(iOS)
    let object = UISearchBar()
    testEventStream(object, keyPath: \.barStyle, values: [.default, .default, .black, .black, .default, .black])
    testEventStream(object, keyPath: \.text, values: Fixtures.strings.map { $0 })
    testEventStream(object, keyPath: \.prompt, values: Fixtures.stringsAndNils)
    testEventStream(object, keyPath: \.placeholder, values: Fixtures.stringsAndNils)
    testEventStream(object, keyPath: \.showsBookmarkButton, values: Fixtures.bools)
    testEventStream(object, keyPath: \.showsCancelButton, values: Fixtures.bools)
    testEventStream(object, keyPath: \.showsSearchResultsButton, values: Fixtures.bools)
    testEventStream(object, keyPath: \.isSearchResultsButtonSelected, values: Fixtures.bools)
    testEventStream(object, keyPath: \.barTintColor, values: Fixtures.colors.map { $0 })
    testEventStream(object, keyPath: \.searchBarStyle,
                    values: [.default, .default, .prominent, .minimal, .minimal, .default])
    #endif
  }

  func testUIImageView() {
    let object = UIImageView()
    testEventStream(object, keyPath: \.image, values: Fixtures.imagesAndNils)
    testEventStream(object, keyPath: \.highlightedImage, values: Fixtures.imagesAndNils)
    testEventStream(object, keyPath: \.isHighlighted, values: Fixtures.bools)
    testEventStream(object, keyPath: \.animationImages, values: Fixtures.arraysOfImagesAndNils)
    testEventStream(object, keyPath: \.highlightedAnimationImages, values: Fixtures.arraysOfImagesAndNils)
    testEventStream(object, keyPath: \.animationDuration, values: Fixtures.timeIntervals)
    testEventStream(object, keyPath: \.animationRepeatCount, values: Fixtures.ints)
    //    testEventSource(object, keyPath: \.isAnimating, values: Fixtures.bool)
  }

  //      func testUIButton() {
  //        for state in Fixtures.uiControlStates {
  //          let object = UIButton()
  //
  //        testOptionalEventDestination(object.rp.title(for: state),
  //                                     object: object,
  //                                     keyPathOrGet: .right({ $0.title(for: state) }),
  //                                     values: Fixtures.stringsAndNils)
  //        testOptionalEventDestination(object.rp.image(for: state),
  //                                     object: object,
  //                                     keyPathOrGet: .right({ $0.image(for: state) }),
  //                                     values: Fixtures.imagesAndNils)
  //        testOptionalEventDestination(object.rp.backgroundImage(for: state),
  //                                     object: object,
  //                                     keyPathOrGet: .right({ $0.backgroundImage(for: state) }),
  //                                     values: Fixtures.imagesAndNils)
  //        testOptionalEventDestination(object.rp.attributedTitle(for: state),
  //                                     object: object,
  //                                     keyPathOrGet: .right({ $0.attributedTitle(for: state) }),
  //                                     values: Fixtures.attributedStrings)
  //        }
  //      }

  //      func testUIBarItem() {
  //        let object = UIBarButtonItem()
  //        testEventStream(object, keyPath: \.isEnabled, values: Fixtures.bools)
  //        testEventStream(object, keyPath: \.title, values: Fixtures.stringsAndNils)
  //        testEventStream(object, keyPath: \.image, values: Fixtures.imagesAndNils)
  //        if #available(iOS 8.0, *) {
  //          testEventStream(object, keyPath: \.landscapeImagePhone, values: Fixtures.imagesAndNils)
  //        }
  //        testEventStream(object, keyPath: \.image, values: Fixtures.imagesAndNils)
  //      testEventDestination(object.rp.titleTextAttributes(for: .normal),
  //                            object: object,
  //                            keyPathOrGet: .right({ $0.titleTextAttributes(for: .normal) }),
  //                            values: /*TODO*/)
  //      }

  func testUILabel() {
    let object = UILabel()
    testEventStream(object, keyPath: \.text, values: Fixtures.strings.map { $0 })
    //        testEventStream(object, keyPath: \.font, values: Fixtures.fonts)
    //        testEventStream(object, keyPath: \.textColor, values: Fixtures.colors)
    //        testEventStream(object, keyPath: \.shadowColor, values: Fixtures.colors)
    testEventStream(object, keyPath: \.shadowOffset, values: Fixtures.shadowOffsets)
    testEventStream(object, keyPath: \.textAlignment, values: Fixtures.textAlignements)
    testEventStream(object, keyPath: \.lineBreakMode, values: Fixtures.lineBreakModes)
    testEventStream(object, keyPath: \.attributedText, values: Fixtures.attributedStrings.map { $0 })
    testEventStream(object, keyPath: \.highlightedTextColor, values: Fixtures.colorsAndNils)
    testEventStream(object, keyPath: \.isHighlighted, values: Fixtures.bools)
    testEventStream(object, keyPath: \.numberOfLines, values: Fixtures.ints)
    testEventStream(object, keyPath: \.baselineAdjustment, values: Fixtures.baselineAdjustments)
  }

  func testUIDatePicker() {
    #if os(iOS)
    let object = UIDatePicker()
    object.datePickerMode = .countDownTimer
    testEventStream(object, keyPath: \.countDownDuration, values: Fixtures.timeIntervals.map { $0 * 60.0 })
    testEventStream(object, keyPath: \.datePickerMode,
                    values: [.time, .time, .date, .date, .dateAndTime, .countDownTimer, .countDownTimer, .dateAndTime])
    testEventStream(object, keyPath: \.locale, values: Fixtures.locales.map { $0 })
    testEventStreamForIUO(object, keyPath: \.calendar, values: Fixtures.calendars.map { $0 })
    testEventStream(object, keyPath: \.timeZone, values: Fixtures.timezonesAndNils)
    testEventStream(object, keyPath: \.date, values: Fixtures.dates)
    testEventStream(object, keyPath: \.minimumDate, values: Fixtures.datesAndNils)
    testEventStream(object, keyPath: \.maximumDate, values: Fixtures.datesAndNils)
    testEventStream(object, keyPath: \.minuteInterval, values: Fixtures.ints)
    #endif
  }

  func testUISwitch() {
    #if os(iOS)
    let object = UISwitch()
    testEventStream(object, keyPath: \.isOn, values: Fixtures.bools)
    testEventStream(object, keyPath: \.onTintColor, values: Fixtures.colorsAndNils)
    testEventStream(object, keyPath: \.thumbTintColor, values: Fixtures.colorsAndNils)
    testEventStream(object, keyPath: \.onImage, values: Fixtures.imagesAndNils)
    testEventStream(object, keyPath: \.offImage, values: Fixtures.imagesAndNils)
    #endif
  }

  func testUIStepper() {
    #if os(iOS)
    let object = UIStepper()
    testEventStream(object, keyPath: \.isContinuous, values: Fixtures.bools)
    testEventStream(object, keyPath: \.autorepeat, values: Fixtures.bools)
    testEventStream(object, keyPath: \.wraps, values: Fixtures.bools)
    testEventStream(object, keyPath: \.value, values: Fixtures.doubles)
    testEventStream(object, keyPath: \.minimumValue, values: Fixtures.doubles)
    testEventStream(object, keyPath: \.maximumValue, values: Fixtures.doubles)
    testEventStream(object, keyPath: \.stepValue, values: Fixtures.doubles.map { $0 + 0.1 })
    for state in Fixtures.uiControlStates {
      let object = UIStepper()

      //    TODO: investigate
      //          testEventDestination(object.rp.backgroundImage(for: state), object: object,
      //                               keyPathOrGet: .right({ $0.backgroundImage(for: state) }),
      //                               values: testImages)
      //            testOptionalEventDestination(object.rp.incrementImage(for: state), object: object,
      //                                         keyPathOrGet: .right({ $0.incrementImage(for: state) }),
      //                                         values: Fixtures.images)
      //            testOptionalEventDestination(object.rp.dividerImage(forLeftSegmentState: state, rightSegmentState: state),
      //                                         object: object,
      //                                         keyPathOrGet:
      //              .right { $0.dividerImage(forLeftSegmentState: state, rightSegmentState: state) },
      //                                         values: Fixtures.images)
      //            testOptionalEventDestination(object.rp.decrementImage(for: state), object: object,
      //                                         keyPathOrGet: .right({ $0.decrementImage(for: state) }),
      //                                         values: Fixtures.images)
    }
    #endif
  }

//  #if os(iOS)
//  func _testUISlider(_ object: UISlider, state: UIControlState) {
//    testOptionalEventDestination(object.rp.thumbImage(for: state), object: object,
//                                 keyPathOrGet: .right({ $0.thumbImage(for: state) }),
//                                 values: Fixtures.imagesAndNils)
//    testOptionalEventDestination(object.rp.minimumTrackImage(for: state), object: object,
//                                 keyPathOrGet: .right({ $0.minimumTrackImage(for: state) }),
//                                 values: Fixtures.imagesAndNils)
//    testOptionalEventDestination(object.rp.maximumTrackImage(for: state), object: object,
//                                 keyPathOrGet: .right({ $0.maximumTrackImage(for: state) }),
//                                 values: Fixtures.imagesAndNils)
//  }
//  #endif

  func testUISlider() {
    #if os(iOS)
    let object = UISlider()
    testEventStream(object, keyPath: \.value, values: Fixtures.floats)
    testEventStream(object, keyPath: \.minimumValue, values: Fixtures.floats)
    testEventStream(object, keyPath: \.maximumValue, values: Fixtures.floats)
    testEventStream(object, keyPath: \.minimumValueImage, values: Fixtures.imagesAndNils)
    testEventStream(object, keyPath: \.maximumValueImage, values: Fixtures.imagesAndNils)
    testEventStream(object, keyPath: \.isContinuous, values: Fixtures.bools)
    testEventStream(object, keyPath: \.minimumTrackTintColor, values: Fixtures.colorsAndNils)
    testEventStream(object, keyPath: \.maximumTrackTintColor, values: Fixtures.colorsAndNils)
    testEventStream(object, keyPath: \.thumbTintColor, values: Fixtures.colorsAndNils)
    //          for state in Fixtures.uiControlStates {
    //            _testUISlider(UISlider(), state: state)
    //          }
    #endif
  }

  func testUIViewController() {
    let object = UIViewController()
    testEventStream(object, keyPath: \.title, values: Fixtures.stringsAndNils)
  }
}

#endif
