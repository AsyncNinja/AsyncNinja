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
      ("testUITextView", testUITextView),
      ("testUISearchBar", testUISearchBar),
      ("testUIImageView", testUIImageView),
      ("testUIButton", testUIButton),
      ("testUIBarItem", testUIBarItem),
      ("testUIDatePicker", testUIDatePicker),
      ("testUILabel", testUILabel),
      ("testUISwitch", testUISwitch),
      ("testUIStepper", testUIStepper),
      ("testUISlider", testUISlider),
      ("testUIViewController", testUIViewController)
    ]

    static let intFixture: [Int] = [1, 1, 2, 2, 3, 1, 4]
    static let timeIntervalFixture: [TimeInterval] = [2, 2, 4, 8, 8, 16, 16]
    static let cgFloatFixture: [CGFloat] = [0.0, 0.0, 0.25, 0.5, 0.5, 1.0, 1.0]
    static let floatFixture: [Float] = [0.0, 0.0, 0.25, 0.5, 0.5, 1.0, 1.0]
    static let doubleFixture: [Double] = [0.0, 0.0, 0.25, 0.5, 0.5, 1.0, 1.0]
    static let boolFixture: [Bool] = [true, true, false, false, true]
    static let stringsAndNilsFixture: [String?] = ["1", nil, "1", "1", "2", "2", nil, nil, "3", "1", "4"]
    static let stringsFixture: [String] = stringsAndNilsFixture.flatMap { $0 }
    static let attributedStringsFixture = iOSTests.stringsFixture
      .map {
        NSAttributedString(string: $0,
                           attributes: [
                            NSFontAttributeName: UIFont.systemFont(ofSize: 14.0)
          ])
    }
    static let colorsAndNilsFiture: [UIColor?]
      = [.white, .white, nil, .red, nil, nil, .green, nil, .green, .blue, .blue]
    static let colorsFiture: [UIColor] = iOSTests.colorsAndNilsFiture.flatMap { $0 }
    static let fontTextStyleFixture: [UIFontTextStyle]
      = [.headline, .subheadline, .body, .footnote, .caption1, .caption2]
    static let fontsFiture: [UIFont] = iOSTests.fontTextStyleFixture
      .map(UIFont.preferredFont(forTextStyle:))
    static let textAlignementFixture: [NSTextAlignment]
      = [.center, .left, .left, .center, .right, .right, .natural, .natural]
    static let lineBreakModeFixture: [NSLineBreakMode] = [
      .byWordWrapping, .byWordWrapping, .byCharWrapping,
      .byCharWrapping, .byClipping, .byTruncatingHead,
      .byWordWrapping, .byTruncatingMiddle, .byTruncatingTail
    ]
    static let baselineAdjustmentFixture: [UIBaselineAdjustment]
      = [.alignBaselines, .alignBaselines, .alignCenters, .alignCenters, .none, .alignBaselines, .alignCenters]
    static let localesFixture: [Locale] = [
      Locale(identifier: "uk"),
      Locale(identifier: "uk"),
      Locale(identifier: "nl"),
      Locale(identifier: "nl"),
      Locale(identifier: "en_US"),
      Locale(identifier: "nl")
    ]
    static let calendarsFixture: [Calendar] = [
      Calendar.current,
      Calendar.current,
      Calendar(identifier: .iso8601),
      Calendar(identifier: .japanese),
      Calendar.current
    ]
    static let timezonesAndNilsFixture: [TimeZone?] = [
      TimeZone.current,
      nil,
      TimeZone.current,
      nil,
      TimeZone(secondsFromGMT: 0),
      TimeZone(secondsFromGMT: 0),
      TimeZone(secondsFromGMT: 60 * 60),
      nil,
      TimeZone.current
    ]

    static func drawTestImage(_ text: String, width: CGFloat = 100, height: CGFloat = 100) -> UIImage {
      return UIImage.draw(size: CGSize(width: width, height: height)) { _ in
        text.draw(at: CGPoint(x: 0, y: 0), withAttributes: [:])
      }
    }
    static let datesAndNilsFixture: [Date?] = [
      Date(timeInterval: 10.0, since: Date()),
      Date(timeInterval: 10.0, since: Date()),
      nil,
      Date(timeInterval: 20.0, since: Date()),
      nil,
      Date(timeInterval: 20.0, since: Date()),
      Date(timeInterval: 10.0, since: Date()),
      nil,
      nil,
      Date(timeInterval: 30.0, since: Date())
    ]
    static let datesFixture: [Date] = iOSTests.datesAndNilsFixture.flatMap { $0 }
    static let shadowOffsetsFixture: [CGSize] = [
      CGSize(width: 0, height: 0),
      CGSize(width: 0, height: 0),
      CGSize(width: 2, height: 3),
      CGSize(width: 2, height: 3),
      CGSize(width: -2, height: -3),
      CGSize(width: 2, height: 3),
      CGSize(width: 0, height: 0)
    ]

    static let imageOne = drawTestImage("1")
    static let imageTwo = drawTestImage("2")
    static let imageThree = drawTestImage("3")
    static let imageFour = drawTestImage("4")
    static let imagesAndNilsFixture: [UIImage?] = [imageOne, nil, imageOne,
                                                   imageOne, imageTwo, imageTwo,
                                                   nil, nil, imageThree,
                                                   imageOne, imageFour]
    static let imagesFixture: [UIImage] = iOSTests.imagesAndNilsFixture.flatMap { $0 }
    static let arraysOfImagesAndNilsFixture: [[UIImage]?] = iOSTests.imagesAndNilsFixture
      .map { $0.map { [$0] } }
    static let uiControlStatesFixture: [UIControlState] = eval {
      var result: [UIControlState] = [.normal, .highlighted, .disabled, .selected]
      if #available(iOS 9.0, *) {
        result.append(.focused)
      }
      return result
    }

    func testUIView() {
      let object = UIView()
      testEventStream(object.rp.alpha,
                      object: object,
                      keyPathOrGetSet: .left("alpha"),
                      values: iOSTests.cgFloatFixture)
      testEventStream(object.rp.tintColor,
                      object: object,
                      keyPathOrGetSet: .left("tintColor"),
                      values: iOSTests.colorsFiture)
      testEventStream(object.rp.isHidden,
                      object: object,
                      keyPathOrGetSet: .left("hidden"),
                      values: iOSTests.boolFixture)
      testEventStream(object.rp.isOpaque,
                      object: object,
                      keyPathOrGetSet: .left("opaque"),
                      values: iOSTests.boolFixture)
      testEventStream(object.rp.isUserInteractionEnabled,
                      object: object,
                      keyPathOrGetSet: .left("userInteractionEnabled"),
                      values: iOSTests.boolFixture)
    }

    func testUIControl() {
      let object = UIControl()
      testEventStream(object.rp.isEnabled,
                      object: object,
                      keyPathOrGetSet: .left("enabled"),
                      values: iOSTests.boolFixture)
      testEventStream(object.rp.isSelected,
                      object: object,
                      keyPathOrGetSet: .left("selected"),
                      values: iOSTests.boolFixture)
    }

    func testUITextField() {
      let object = UITextField()
      let attributedStringsFixture = iOSTests.stringsFixture
        .map { NSAttributedString(string: $0, attributes: object.defaultTextAttributes) }
      testEventStream(object.rp.text,
                      object: object,
                      keyPathOrGetSet: .left("text"),
                      values: iOSTests.stringsFixture)
      testEventStream(object.rp.attributedText,
                      object: object,
                      keyPathOrGetSet: .left("attributedText"),
                      values: attributedStringsFixture)
      testEventStream(object.rp.textColor,
                      object: object,
                      keyPathOrGetSet: .left("textColor"),
                      values: iOSTests.colorsFiture)
      testEventStream(object.rp.font,
                      object: object,
                      keyPathOrGetSet: .left("font"),
                      values: iOSTests.fontsFiture)
      testEventStream(object.rp.textAlignment,
                      object: object,
                      keyPathOrGetSet: .right(getter: { $0.textAlignment }, setter: { $0.textAlignment = $1! }),
                      values: iOSTests.textAlignementFixture)
      testEventStream(object.rp.placeholder,
                      object: object,
                      keyPathOrGetSet: .left("placeholder"),
                      values: iOSTests.stringsAndNilsFixture)
      testEventStream(object.rp.attributedPlaceholder,
                      object: object,
                      keyPathOrGetSet: .left("attributedPlaceholder"),
                      values: attributedStringsFixture)
      testEventStream(object.rp.background,
                      object: object,
                      keyPathOrGetSet: .left("background"),
                      values: iOSTests.imagesAndNilsFixture)
      testEventStream(object.rp.disabledBackground,
                      object: object,
                      keyPathOrGetSet: .left("disabledBackground"),
                      values: iOSTests.imagesAndNilsFixture)
    }

    func testUITextView() {
      let object = UITextView()

      testEventStream(object.rp.text,
                      object: object,
                      keyPathOrGetSet: .left("text"),
                      values: iOSTests.stringsFixture)
      testEventStream(object.rp.font,
                      object: object,
                      keyPathOrGetSet: .left("font"),
                      values: iOSTests.fontsFiture)
      testEventStream(object.rp.textColor,
                      object: object,
                      keyPathOrGetSet: .left("textColor"),
                      values: iOSTests.colorsAndNilsFiture)
      testEventStream(object.rp.textAlignment,
                      object: object,
                      keyPathOrGetSet: .right(getter: { $0.textAlignment }, setter: { $0.textAlignment = $1! }),
                      values: iOSTests.textAlignementFixture)
      testEventStream(object.rp.isEditable,
                      object: object,
                      keyPathOrGetSet: .left("editable"),
                      values: iOSTests.boolFixture)
      testEventStream(object.rp.isSelectable,
                      object: object,
                      keyPathOrGetSet: .left("selectable"),
                      values: iOSTests.boolFixture)
      testEventStream(object.rp.attributedText,
                      object: object,
                      keyPathOrGetSet: .left("attributedText"),
                      values: iOSTests.attributedStringsFixture)
      testEventStream(object.rp.clearsOnInsertion,
                      object: object,
                      keyPathOrGetSet: .left("clearsOnInsertion"),
                      values: iOSTests.boolFixture)
    }

    func testUISearchBar() {
      #if os(iOS)
        let object = UISearchBar()

        testEventStream(object.rp.barStyle,
                        object: object,
                        keyPathOrGetSet: .right(getter: { $0.barStyle }, setter: { $0.barStyle = $1! }),
                        values: [.default, .default, .black, .black, .default, .black])
        testEventStream(object.rp.text,
                        object: object,
                        keyPathOrGetSet: .left("text"),
                        values: iOSTests.stringsFixture)
        testEventStream(object.rp.prompt,
                        object: object,
                        keyPathOrGetSet: .left("prompt"),
                        values: iOSTests.stringsAndNilsFixture)
        testEventStream(object.rp.placeholder,
                        object: object,
                        keyPathOrGetSet: .left("placeholder"),
                        values: iOSTests.stringsAndNilsFixture)
        testEventStream(object.rp.showsBookmarkButton,
                        object: object,
                        keyPathOrGetSet: .left("showsBookmarkButton"),
                        values: iOSTests.boolFixture)
        testEventStream(object.rp.showsCancelButton,
                        object: object,
                        keyPathOrGetSet: .left("showsCancelButton"),
                        values: iOSTests.boolFixture)
        testEventStream(object.rp.showsSearchResultsButton,
                        object: object,
                        keyPathOrGetSet: .left("showsSearchResultsButton"),
                        values: iOSTests.boolFixture)
        testEventStream(object.rp.isSearchResultsButtonSelected,
                        object: object,
                        keyPathOrGetSet: .left("searchResultsButtonSelected"),
                        values: iOSTests.boolFixture)
        testEventStream(object.rp.barTintColor,
                        object: object,
                        keyPathOrGetSet: .left("barTintColor"),
                        values: iOSTests.colorsFiture)
        testEventStream(object.rp.searchBarStyle,
                        object: object,
                        keyPathOrGetSet: .right(getter: { $0.searchBarStyle }, setter: { $0.searchBarStyle = $1! }),
                        values: [.default, .default, .prominent, .minimal, .minimal, .default])
      #endif
    }

    func testUIImageView() {
      let object = UIImageView()

      testEventStream(object.rp.image,
                      object: object,
                      keyPathOrGetSet: .left("image"),
                      values: iOSTests.imagesAndNilsFixture)
      testEventStream(object.rp.highlightedImage,
                      object: object,
                      keyPathOrGetSet: .left("highlightedImage"),
                      values: iOSTests.imagesAndNilsFixture)
      testEventStream(object.rp.isHighlighted,
                      object: object,
                      keyPathOrGetSet: .left("highlighted"),
                      values: iOSTests.boolFixture)
      //      self.testEventsDestination(updatable: object.rp.animationImages,
      //                                 object: object,
      //                                 keyPath: "animationImages",
      //                                 values: iOSTests.arraysOfImagesAndNilsFixture)
      //      self.testEventsDestination(updatable: object.rp.highlightedAnimationImages,
      //                                 object: object,
      //                                 keyPath: "highlightedAnimationImages",
      //                                 values: iOSTests.arraysOfImagesAndNilsFixture)
      testEventStream(object.rp.animationDuration,
                      object: object,
                      keyPathOrGetSet: .left("animationDuration"),
                      values: iOSTests.timeIntervalFixture)
      testEventStream(object.rp.animationRepeatCount,
                      object: object,
                      keyPathOrGetSet: .left("animationRepeatCount"),
                      values: iOSTests.intFixture)
      //      self.testEventsDestination(updatable: object.rp.isAnimating,
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

    func testUIButton() {
      for state in iOSTests.uiControlStatesFixture {
        let object = UIButton()

        testEventsDestination(object.rp.title(for: state),
                              object: object,
                              keyPathOrGet: .right({ $0.title(for: state) }),
                              values: iOSTests.stringsAndNilsFixture)
        testEventsDestination(object.rp.image(for: state),
                              object: object,
                              keyPathOrGet: .right({ $0.image(for: state) }),
                              values: iOSTests.imagesAndNilsFixture)
        testEventsDestination(object.rp.backgroundImage(for: state),
                              object: object,
                              keyPathOrGet: .right({ $0.backgroundImage(for: state) }),
                              values: iOSTests.imagesAndNilsFixture)
        testEventsDestination(object.rp.attributedTitle(for: state),
                              object: object,
                              keyPathOrGet: .right({ $0.attributedTitle(for: state) }),
                              values: iOSTests.attributedStringsFixture)
      }
    }

    func testUIBarItem() {
      let object = UIBarButtonItem()
      testEventStream(object.rp.isEnabled,
                      object: object,
                      keyPathOrGetSet: .left("enabled"),
                      values: iOSTests.boolFixture)
      testEventStream(object.rp.title,
                      object: object,
                      keyPathOrGetSet: .left("title"),
                      values: iOSTests.stringsAndNilsFixture)
      testEventStream(object.rp.image,
                      object: object,
                      keyPathOrGetSet: .left("image"),
                      values: iOSTests.imagesAndNilsFixture)
      if #available(iOS 8.0, *) {
        testEventStream(object.rp.landscapeImagePhone,
                        object: object,
                        keyPathOrGetSet: .left("landscapeImagePhone"),
                        values: iOSTests.imagesAndNilsFixture)
      }
      testEventStream(object.rp.image,
                      object: object,
                      keyPathOrGetSet: .left("image"),
                      values: iOSTests.imagesAndNilsFixture)
      //      testEventsDestination(object.rp.titleTextAttributes(for: .normal),
      //                            object: object,
      //                            keyPathOrGet: .right({ $0.titleTextAttributes(for: .normal) }),
      //                            values: /*TODO*/)
    }

    func testUILabel() {
      let object = UILabel()

      testEventStream(object.rp.text,
                      object: object,
                      keyPathOrGetSet: .left("text"),
                      values: iOSTests.stringsFixture)
      testEventStream(object.rp.font,
                      object: object,
                      keyPathOrGetSet: .left("font"),
                      values: iOSTests.fontsFiture)
      testEventStream(object.rp.textColor,
                      object: object,
                      keyPathOrGetSet: .left("textColor"),
                      values: iOSTests.colorsFiture)
      testEventStream(object.rp.shadowColor,
                      object: object,
                      keyPathOrGetSet: .left("shadowColor"),
                      values: iOSTests.colorsAndNilsFiture)
      testEventStream(object.rp.shadowOffset,
                      object: object,
                      keyPathOrGetSet: .right(getter: { $0.shadowOffset }, setter: { $0.shadowOffset = $1! }),
                      values: iOSTests.shadowOffsetsFixture)
      testEventStream(object.rp.textAlignment,
                      object: object,
                      keyPathOrGetSet: .right(getter: { $0.textAlignment }, setter: { $0.textAlignment = $1! }),
                      values: iOSTests.textAlignementFixture)
      testEventStream(object.rp.lineBreakMode,
                      object: object,
                      keyPathOrGetSet: .right(getter: { $0.lineBreakMode }, setter: { $0.lineBreakMode = $1! }),
                      values: iOSTests.lineBreakModeFixture)
      testEventStream(object.rp.attributedText,
                      object: object,
                      keyPathOrGetSet: .left("attributedText"),
                      values: iOSTests.attributedStringsFixture)
      testEventStream(object.rp.highlightedTextColor,
                      object: object,
                      keyPathOrGetSet: .left("highlightedTextColor"),
                      values: iOSTests.colorsAndNilsFiture)
      testEventStream(object.rp.isHighlighted,
                      object: object,
                      keyPathOrGetSet: .left("highlighted"),
                      values: iOSTests.boolFixture)
      testEventStream(object.rp.numberOfLines,
                      object: object,
                      keyPathOrGetSet: .left("numberOfLines"),
                      values: iOSTests.intFixture)
      testEventStream(object.rp.baselineAdjustment,
                      object: object,
                      keyPathOrGetSet: .right(
                        getter: { $0.baselineAdjustment },
                        setter: { $0.baselineAdjustment = $1! }),
                      values: iOSTests.baselineAdjustmentFixture)
    }

    func testUIDatePicker() {
      #if os(iOS)
        let object = UIDatePicker()

        let datePickerModeFixtures: [UIDatePickerMode] = [
          .time, .time, .date, .date, .dateAndTime, .countDownTimer, .countDownTimer, .dateAndTime
        ]
        testEventStream(object.rp.datePickerMode,
                        object: object,
                        keyPathOrGetSet: .right(getter: { $0.datePickerMode }, setter: { $0.datePickerMode = $1! }),
                        values: datePickerModeFixtures)
        testEventStream(object.rp.locale,
                        object: object,
                        keyPathOrGetSet: .left("locale"),
                        values: iOSTests.localesFixture)
        testEventStream(object.rp.calendar,
                        object: object,
                        keyPathOrGetSet: .left("calendar"),
                        values: iOSTests.calendarsFixture)
        testEventStream(object.rp.timeZone,
                        object: object,
                        keyPathOrGetSet: .left("timeZone"),
                        values: iOSTests.timezonesAndNilsFixture)
        testEventStream(object.rp.date,
                        object: object,
                        keyPathOrGetSet: .left("date"),
                        values: iOSTests.datesFixture)
        testEventsDestination(object.rp.minimumDate,
                              object: object,
                              keyPathOrGet: .left("minimumDate"),
                              values: iOSTests.datesAndNilsFixture)
        testEventsDestination(object.rp.maximumDate,
                              object: object,
                              keyPathOrGet: .left("maximumDate"),
                              values: iOSTests.datesAndNilsFixture)
        //      TODO: Investigate
        //      object.datePickerMode = .countDownTimer
        //      testEventStream(object.rp.countDownDuration,
        //               object: object,
        //               keyPathOrGetSet: .left("countDownDuration"),
        //               values: iOSTests.timeIntervalFixture)
        testEventStream(object.rp.minuteInterval,
                        object: object,
                        keyPathOrGetSet: .left("minuteInterval"),
                        values: iOSTests.intFixture)
      #endif
    }

    func testUISwitch() {
      #if os(iOS)
        let object = UISwitch()

        testEventStream(object.rp.isOn,
                        object: object,
                        keyPathOrGetSet: .left("on"),
                        values: iOSTests.boolFixture)
        testEventStream(object.rp.onTintColor,
                        object: object,
                        keyPathOrGetSet: .left("onTintColor"),
                        values: iOSTests.colorsAndNilsFiture)
        testEventStream(object.rp.thumbTintColor,
                        object: object,
                        keyPathOrGetSet: .left("thumbTintColor"),
                        values: iOSTests.colorsAndNilsFiture)
        testEventStream(object.rp.onImage,
                        object: object,
                        keyPathOrGetSet: .left("onImage"),
                        values: iOSTests.imagesAndNilsFixture)
        testEventStream(object.rp.offImage,
                        object: object,
                        keyPathOrGetSet: .left("offImage"),
                        values: iOSTests.imagesAndNilsFixture)
      #endif
    }

    func testUIStepper() {
      #if os(iOS)
        let object = UIStepper()

        testEventStream(object.rp.isContinuous,
                        object: object,
                        keyPathOrGetSet: .left("continuous"),
                        values: iOSTests.boolFixture)
        testEventStream(object.rp.autorepeat,
                        object: object,
                        keyPathOrGetSet: .left("autorepeat"),
                        values: iOSTests.boolFixture)
        testEventStream(object.rp.wraps,
                        object: object,
                        keyPathOrGetSet: .left("wraps"),
                        values: iOSTests.boolFixture)
        testEventStream(object.rp.value,
                        object: object,
                        keyPathOrGetSet: .left("value"),
                        values: iOSTests.doubleFixture)
        testEventStream(object.rp.minimumValue,
                        object: object,
                        keyPathOrGetSet: .left("minimumValue"),
                        values: iOSTests.doubleFixture)
        testEventStream(object.rp.maximumValue,
                        object: object,
                        keyPathOrGetSet: .left("maximumValue"),
                        values: iOSTests.doubleFixture.map { $0 + 100.0 })
        testEventStream(object.rp.stepValue,
                        object: object,
                        keyPathOrGetSet: .left("stepValue"),
                        values: iOSTests.doubleFixture.map { $0 + 0.1 })
        for state in iOSTests.uiControlStatesFixture {
          let object = UIStepper()

          //    TODO: investigate
          //        testEventsDestination(object.rp.backgroundImage(for: state),
          //                              object: object,
          //                              keyPathOrGet: .right({ $0.backgroundImage(for: state) }),
          //                              values: testImages)
          testEventsDestination(object.rp.incrementImage(for: state),
                                object: object,
                                keyPathOrGet: .right({ $0.incrementImage(for: state) }),
                                values: iOSTests.imagesFixture)
          testEventsDestination(object.rp.dividerImage(forLeftSegmentState: state, rightSegmentState: state),
                                object: object,
                                keyPathOrGet:
            .right { $0.dividerImage(forLeftSegmentState: state, rightSegmentState: state) },
                                values: iOSTests.imagesFixture)
          testEventsDestination(object.rp.decrementImage(for: state),
                                object: object,
                                keyPathOrGet: .right({ $0.decrementImage(for: state) }),
                                values: iOSTests.imagesFixture)
        }
      #endif
    }

    func testUISlider() {
      #if os(iOS)
        let object = UISlider()

        testEventStream(object.rp.value,
                        object: object,
                        keyPathOrGetSet: .left("value"),
                        values: iOSTests.floatFixture)
        testEventStream(object.rp.minimumValue,
                        object: object,
                        keyPathOrGetSet: .left("minimumValue"),
                        values: iOSTests.floatFixture)
        testEventStream(object.rp.minimumValue,
                        object: object,
                        keyPathOrGetSet: .left("minimumValue"),
                        values: iOSTests.floatFixture)
        testEventStream(object.rp.minimumValueImage,
                        object: object,
                        keyPathOrGetSet: .left("minimumValueImage"),
                        values: iOSTests.imagesAndNilsFixture)
        testEventStream(object.rp.maximumValueImage,
                        object: object,
                        keyPathOrGetSet: .left("maximumValueImage"),
                        values: iOSTests.imagesAndNilsFixture)
        testEventStream(object.rp.isContinuous,
                        object: object,
                        keyPathOrGetSet: .left("continuous"),
                        values: iOSTests.boolFixture)
        testEventStream(object.rp.minimumTrackTintColor,
                        object: object,
                        keyPathOrGetSet: .left("minimumTrackTintColor"),
                        values: iOSTests.colorsAndNilsFiture)
        testEventStream(object.rp.maximumTrackTintColor,
                        object: object,
                        keyPathOrGetSet: .left("maximumTrackTintColor"),
                        values: iOSTests.colorsAndNilsFiture)
        testEventStream(object.rp.thumbTintColor,
                        object: object,
                        keyPathOrGetSet: .left("thumbTintColor"),
                        values: iOSTests.colorsAndNilsFiture)
        for state in iOSTests.uiControlStatesFixture {
          let object = UISlider()

          testEventsDestination(object.rp.thumbImage(for: state),
                                object: object,
                                keyPathOrGet: .right({ $0.thumbImage(for: state) }),
                                values: iOSTests.imagesAndNilsFixture)
          testEventsDestination(object.rp.minimumTrackImage(for: state),
                                object: object,
                                keyPathOrGet: .right({ $0.minimumTrackImage(for: state) }),
                                values: iOSTests.imagesAndNilsFixture)
          testEventsDestination(object.rp.maximumTrackImage(for: state),
                                object: object,
                                keyPathOrGet: .right({ $0.maximumTrackImage(for: state) }),
                                values: iOSTests.imagesAndNilsFixture)
        }
      #endif
    }

    func testUIViewController() {
      let object = UIViewController()
      testEventStream(object.rp.title,
                      object: object,
                      keyPathOrGetSet: .left("title"),
                      values: iOSTests.stringsAndNilsFixture)
    }
  }

  // MARK: - T: Equatable
  extension iOSTests {
    func testEventStream<T: EventsDestination&EventSource, Object: NSObject>(
      _ stream: T,
      object: Object,
      keyPathOrGetSet: Either<String, (getter: (Object) -> T.Update?, setter: (Object, T.Update?) -> Void)>,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line
      ) where T.Update: Equatable {
      testEventsDestination(stream, object: object, keyPathOrGet: keyPathOrGetSet.mapRight { $0.getter },
                            values: values, file: file, line: line)
      testEventSource(stream, object: object, keyPathOrSet: keyPathOrGetSet.mapRight { $0.setter },
                      values: values, file: file, line: line)
    }

    func testEventsDestination<T: EventsDestination, Object: NSObject>(
      _ eventsDestination: T,
      object: Object,
      keyPathOrGet: Either<String, (Object) -> T.Update?>,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line
      ) where T.Update: Equatable {
      for value in values {
        eventsDestination.update(value, from: .main)
        let objectValue: T.Update? = eval {
          switch keyPathOrGet {
          case let .left(keyPath):
            return object.value(forKeyPath: keyPath) as? T.Update
          case let .right(getter):
            return getter(object)
          }
        }
        XCTAssertEqual(objectValue, value, file: file, line: line)
      }
    }

    func testEventSource<T: EventSource, Object: NSObject>(
      _ EventSource: T,
      object: Object,
      keyPathOrSet: Either<String, (Object, T.Update?) -> Void>,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line
      ) where T.Update: Equatable {
      var updatingIterator = EventSource.makeIterator()
      _ = updatingIterator.next() // skip an initial value
      for value in values {
        switch keyPathOrSet {
        case let .left(keyPath):
          object.setValue(value, forKeyPath: keyPath)
        case let .right(setter):
          setter(object, value)
        }

        XCTAssertEqual(updatingIterator.next() as! T.Update?, value, file: file, line: line)
      }
    }

  }

  // MARK: - T: Optional<Equatable>
  extension iOSTests {
    func testEventStream<T: EventsDestination&EventSource, Object: NSObject>(
      _ stream: T,
      object: Object,
      keyPathOrGetSet: Either<String, (getter: (Object) -> T.Update?, setter: (Object, T.Update?) -> Void)>,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line
      ) where T.Update: AsyncNinjaOptionalAdaptor,
      T.Update.AsyncNinjaWrapped: Equatable {
        testEventsDestination(stream, object: object, keyPathOrGet: keyPathOrGetSet.mapRight { $0.getter },
                              values: values, file: file, line: line)
        testEventSource(stream, object: object, keyPathOrSet: keyPathOrGetSet.mapRight { $0.setter },
                        values: values, file: file, line: line)
    }

    func testEventsDestination<T: EventsDestination, Object: NSObject>(
      _ eventsDestination: T,
      object: Object,
      keyPathOrGet: Either<String, (Object) -> T.Update?>,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line,
      customGetter: ((Object) -> T.Update?)? = nil
      ) where T.Update: AsyncNinjaOptionalAdaptor,
      T.Update.AsyncNinjaWrapped: Equatable {
        for value in values {
          eventsDestination.update(value, from: .main)
          let objectValue: T.Update? = eval {
            switch keyPathOrGet {
            case let .left(keyPath):
              return object.value(forKeyPath: keyPath) as? T.Update
            case let .right(getter):
              return getter(object)
            }
          }
          XCTAssertEqual(objectValue?.asyncNinjaOptionalValue, value.asyncNinjaOptionalValue, file: file, line: line)
        }
    }

    func testEventSource<T: EventSource, Object: NSObject>(
      _ EventSource: T,
      object: Object,
      keyPathOrSet: Either<String, (Object, T.Update?) -> Void>,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line
      ) where T.Update: AsyncNinjaOptionalAdaptor,
      T.Update.AsyncNinjaWrapped: Equatable {
        var updatingIterator = EventSource.makeIterator()
        _ = updatingIterator.next() // skip an initial value
        for value in values {
          switch keyPathOrSet {
          case let .left(keyPath):
            object.setValue(value.asyncNinjaOptionalValue, forKeyPath: keyPath)
          case let .right(setter):
            setter(object, value)
          }

          XCTAssertEqual((updatingIterator.next() as! T.Update?)?.asyncNinjaOptionalValue,
                         value.asyncNinjaOptionalValue, file: file, line: line)
        }
    }
  }

  extension UIImage {
    class func draw(size: CGSize, opaque: Bool = false, scale: CGFloat = 0.0, drawer: (CGContext) -> Void) -> UIImage {
      UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
      defer { UIGraphicsEndImageContext(); }
      drawer(UIGraphicsGetCurrentContext()!)
      return UIGraphicsGetImageFromCurrentImageContext()!
    }
  }

#endif
