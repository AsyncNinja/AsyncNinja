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

    func testUIView() {
      let object = UIView()
      testEventStream(object.rp.alpha,
                      object: object,
                      keyPathOrGetSet: .left("alpha"),
                      values: Fixtures.cgFloats)
      testEventStream(object.rp.tintColor,
                      object: object,
                      keyPathOrGetSet: .left("tintColor"),
                      values: Fixtures.colors)
      testEventStream(object.rp.isHidden,
                      object: object,
                      keyPathOrGetSet: .left("hidden"),
                      values: Fixtures.bools)
      testEventStream(object.rp.isOpaque,
                      object: object,
                      keyPathOrGetSet: .left("opaque"),
                      values: Fixtures.bools)
      testEventStream(object.rp.isUserInteractionEnabled,
                      object: object,
                      keyPathOrGetSet: .left("userInteractionEnabled"),
                      values: Fixtures.bools)
    }

    func testUIControl() {
      let object = UIControl()
      testEventStream(object.rp.isEnabled,
                      object: object,
                      keyPathOrGetSet: .left("enabled"),
                      values: Fixtures.bools)
      testEventStream(object.rp.isSelected,
                      object: object,
                      keyPathOrGetSet: .left("selected"),
                      values: Fixtures.bools)
    }

    func testUITextField() {
      let object = UITextField()
      let defaultTextAttributes: [NSAttributedStringKey: Any] = Dictionary(uniqueKeysWithValues:
        object.defaultTextAttributes.map { (NSAttributedStringKey($0.key), $0.value) })
      let attributedStringsFixtures = Fixtures.strings
        .map { NSAttributedString(string: $0, attributes: defaultTextAttributes) }
      testEventStream(object.rp.text,
                      object: object,
                      keyPathOrGetSet: .left("text"),
                      values: Fixtures.strings)
      testOptionalEventStream(object.rp.attributedText,
                              object: object,
                              keyPathOrGetSet: .left("attributedText"),
                              values: attributedStringsFixtures)
      testOptionalEventStream(object.rp.textColor,
                              object: object,
                              keyPathOrGetSet: .left("textColor"),
                              values: Fixtures.colors)
      testEventStream(object.rp.font,
                      object: object,
                      keyPathOrGetSet: .left("font"),
                      values: Fixtures.fonts)
      testEventStream(object.rp.textAlignment,
                      object: object,
                      keyPathOrGetSet: .right((getter: { $0.textAlignment }, setter: { $0.textAlignment = $1! })),
                      values: Fixtures.textAlignements)
      testOptionalEventStream(object.rp.placeholder,
                              object: object,
                              keyPathOrGetSet: .left("placeholder"),
                              values: Fixtures.stringsAndNils)
      testOptionalEventStream(object.rp.attributedPlaceholder,
                              object: object,
                              keyPathOrGetSet: .left("attributedPlaceholder"),
                              values: attributedStringsFixtures)
      testOptionalEventStream(object.rp.background,
                              object: object,
                              keyPathOrGetSet: .left("background"),
                              values: Fixtures.imagesAndNils)
      testOptionalEventStream(object.rp.disabledBackground,
                              object: object,
                              keyPathOrGetSet: .left("disabledBackground"),
                              values: Fixtures.imagesAndNils)
    }

    func testUITextView() {
      let object = UITextView()

      testEventStream(object.rp.text,
                      object: object,
                      keyPathOrGetSet: .left("text"),
                      values: Fixtures.strings)
      testEventStream(object.rp.font,
                      object: object,
                      keyPathOrGetSet: .left("font"),
                      values: Fixtures.fonts)
      testOptionalEventStream(object.rp.textColor,
                              object: object,
                              keyPathOrGetSet: .left("textColor"),
                              values: Fixtures.colorsAndNils)
      testEventStream(object.rp.textAlignment,
                      object: object,
                      keyPathOrGetSet: .right((getter: { $0.textAlignment }, setter: { $0.textAlignment = $1! })),
                      values: Fixtures.textAlignements)
      testEventStream(object.rp.isEditable,
                      object: object,
                      keyPathOrGetSet: .left("editable"),
                      values: Fixtures.bools)
      testEventStream(object.rp.isSelectable,
                      object: object,
                      keyPathOrGetSet: .left("selectable"),
                      values: Fixtures.bools)
      testEventStream(object.rp.attributedText,
                      object: object,
                      keyPathOrGetSet: .left("attributedText"),
                      values: Fixtures.attributedStrings)
      testEventStream(object.rp.clearsOnInsertion,
                      object: object,
                      keyPathOrGetSet: .left("clearsOnInsertion"),
                      values: Fixtures.bools)
    }

    func testUISearchBar() {
      #if os(iOS)
        let object = UISearchBar()

        testEventStream(object.rp.barStyle, object: object,
                        keyPathOrGetSet: .right((getter: { $0.barStyle }, setter: { $0.barStyle = $1! })),
                        values: [.default, .default, .black, .black, .default, .black])
        testEventStream(object.rp.text, object: object,
                        keyPathOrGetSet: .left("text"),
                        values: Fixtures.strings)
        testOptionalEventStream(object.rp.prompt, object: object,
                                keyPathOrGetSet: .left("prompt"),
                                values: Fixtures.stringsAndNils)
        testOptionalEventStream(object.rp.placeholder, object: object,
                                keyPathOrGetSet: .left("placeholder"),
                                values: Fixtures.stringsAndNils)
        testEventStream(object.rp.showsBookmarkButton, object: object,
                        keyPathOrGetSet: .left("showsBookmarkButton"),
                        values: Fixtures.bools)
        testEventStream(object.rp.showsCancelButton, object: object,
                        keyPathOrGetSet: .left("showsCancelButton"),
                        values: Fixtures.bools)
        testEventStream(object.rp.showsSearchResultsButton, object: object,
                        keyPathOrGetSet: .left("showsSearchResultsButton"),
                        values: Fixtures.bools)
        testEventStream(object.rp.isSearchResultsButtonSelected, object: object,
                        keyPathOrGetSet: .left("searchResultsButtonSelected"),
                        values: Fixtures.bools)
        testEventStream(object.rp.barTintColor, object: object,
                        keyPathOrGetSet: .left("barTintColor"),
                        values: Fixtures.colors)
        testEventStream(object.rp.searchBarStyle, object: object,
                        keyPathOrGetSet: .right((getter: { $0.searchBarStyle }, setter: { $0.searchBarStyle = $1! })),
                        values: [.default, .default, .prominent, .minimal, .minimal, .default])
      #endif
    }

    func testUIImageView() {
      let object = UIImageView()

      testOptionalEventStream(object.rp.image,
                              object: object,
                              keyPathOrGetSet: .left("image"),
                              values: Fixtures.imagesAndNils)
      testOptionalEventStream(object.rp.highlightedImage,
                              object: object,
                              keyPathOrGetSet: .left("highlightedImage"),
                              values: Fixtures.imagesAndNils)
      testEventStream(object.rp.isHighlighted,
                      object: object,
                      keyPathOrGetSet: .left("highlighted"),
                      values: Fixtures.bools)
      //      self.testEventDestination(updatable: object.rp.animationImages,
      //                                 object: object,
      //                                 keyPath: "animationImages",
      //                                 values: Fixtures.arraysOfImagesAndNilsFixture)
      //      self.testEventDestination(updatable: object.rp.highlightedAnimationImages,
      //                                 object: object,
      //                                 keyPath: "highlightedAnimationImages",
      //                                 values: Fixtures.arraysOfImagesAndNilsFixture)
      testEventStream(object.rp.animationDuration,
                      object: object,
                      keyPathOrGetSet: .left("animationDuration"),
                      values: Fixtures.timeIntervals)
      testEventStream(object.rp.animationRepeatCount,
                      object: object,
                      keyPathOrGetSet: .left("animationRepeatCount"),
                      values: Fixtures.ints)
      //      self.testEventDestination(updatable: object.rp.isAnimating,
      //                                 object: object,
      //                                 keyPath: "animating",
      //                                 values: Fixtures.boolFixture,
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
      for state in Fixtures.uiControlStates {
        let object = UIButton()

        testOptionalEventDestination(object.rp.title(for: state),
                                     object: object,
                                     keyPathOrGet: .right({ $0.title(for: state) }),
                                     values: Fixtures.stringsAndNils)
        testOptionalEventDestination(object.rp.image(for: state),
                                     object: object,
                                     keyPathOrGet: .right({ $0.image(for: state) }),
                                     values: Fixtures.imagesAndNils)
        testOptionalEventDestination(object.rp.backgroundImage(for: state),
                                     object: object,
                                     keyPathOrGet: .right({ $0.backgroundImage(for: state) }),
                                     values: Fixtures.imagesAndNils)
        testOptionalEventDestination(object.rp.attributedTitle(for: state),
                                     object: object,
                                     keyPathOrGet: .right({ $0.attributedTitle(for: state) }),
                                     values: Fixtures.attributedStrings)
      }
    }

    func testUIBarItem() {
      let object = UIBarButtonItem()
      testEventStream(object.rp.isEnabled,
                      object: object,
                      keyPathOrGetSet: .left("enabled"),
                      values: Fixtures.bools)
      testOptionalEventStream(object.rp.title,
                              object: object,
                              keyPathOrGetSet: .left("title"),
                              values: Fixtures.stringsAndNils)
      testOptionalEventStream(object.rp.image,
                              object: object,
                              keyPathOrGetSet: .left("image"),
                              values: Fixtures.imagesAndNils)
      if #available(iOS 8.0, *) {
        testOptionalEventStream(object.rp.landscapeImagePhone,
                                object: object,
                                keyPathOrGetSet: .left("landscapeImagePhone"),
                                values: Fixtures.imagesAndNils)
      }
      testOptionalEventStream(object.rp.image,
                              object: object,
                              keyPathOrGetSet: .left("image"),
                              values: Fixtures.imagesAndNils)
      //      testEventDestination(object.rp.titleTextAttributes(for: .normal),
      //                            object: object,
      //                            keyPathOrGet: .right({ $0.titleTextAttributes(for: .normal) }),
      //                            values: /*TODO*/)
    }

    func testUILabel() {
      let object = UILabel()

      testEventStream(object.rp.text, object: object,
                      keyPathOrGetSet: .left("text"),
                      values: Fixtures.strings)
      testEventStream(object.rp.font, object: object,
                      keyPathOrGetSet: .left("font"),
                      values: Fixtures.fonts)
      testOptionalEventStream(object.rp.textColor, object: object,
                              keyPathOrGetSet: .left("textColor"),
                              values: Fixtures.colors)
      testOptionalEventStream(object.rp.shadowColor, object: object,
                              keyPathOrGetSet: .left("shadowColor"),
                              values: Fixtures.colorsAndNils)
      testEventStream(object.rp.shadowOffset, object: object,
                      keyPathOrGetSet: .right((getter: { $0.shadowOffset }, setter: { $0.shadowOffset = $1! })),
                      values: Fixtures.shadowOffsets)
      testEventStream(object.rp.textAlignment, object: object,
                      keyPathOrGetSet: .right((getter: { $0.textAlignment }, setter: { $0.textAlignment = $1! })),
                      values: Fixtures.textAlignements)
      testEventStream(object.rp.lineBreakMode, object: object,
                      keyPathOrGetSet: .right((getter: { $0.lineBreakMode }, setter: { $0.lineBreakMode = $1! })),
                      values: Fixtures.lineBreakModes)
      testOptionalEventStream(object.rp.attributedText, object: object,
                              keyPathOrGetSet: .left("attributedText"),
                              values: Fixtures.attributedStrings)
      testOptionalEventStream(object.rp.highlightedTextColor, object: object,
                              keyPathOrGetSet: .left("highlightedTextColor"),
                              values: Fixtures.colorsAndNils)
      testEventStream(object.rp.isHighlighted, object: object,
                      keyPathOrGetSet: .left("highlighted"),
                      values: Fixtures.bools)
      testEventStream(object.rp.numberOfLines, object: object,
                      keyPathOrGetSet: .left("numberOfLines"),
                      values: Fixtures.ints)
      testEventStream(object.rp.baselineAdjustment, object: object,
                      keyPathOrGetSet: .right((
                        getter: { $0.baselineAdjustment },
                        setter: { $0.baselineAdjustment = $1! })),
                      values: Fixtures.baselineAdjustments)
    }

    func testUIDatePicker() {
      #if os(iOS)
        let object = UIDatePicker()

        let datePickerModeFixtures: [UIDatePickerMode] = [
          .time, .time, .date, .date, .dateAndTime, .countDownTimer, .countDownTimer, .dateAndTime
        ]
        testEventStream(object.rp.datePickerMode,
                        object: object,
                        keyPathOrGetSet: .right((getter: { $0.datePickerMode }, setter: { $0.datePickerMode = $1! })),
                        values: datePickerModeFixtures)
        testEventStream(object.rp.locale,
                        object: object,
                        keyPathOrGetSet: .left("locale"),
                        values: Fixtures.locales)
        testEventStream(object.rp.calendar,
                        object: object,
                        keyPathOrGetSet: .left("calendar"),
                        values: Fixtures.calendars)
        testOptionalEventStream(object.rp.timeZone,
                                object: object,
                                keyPathOrGetSet: .left("timeZone"),
                                values: Fixtures.timezonesAndNils)
        testEventStream(object.rp.date,
                        object: object,
                        keyPathOrGetSet: .left("date"),
                        values: Fixtures.dates)
        testOptionalEventDestination(object.rp.minimumDate,
                                     object: object,
                                     keyPathOrGet: .left("minimumDate"),
                                     values: Fixtures.datesAndNils)
        testOptionalEventDestination(object.rp.maximumDate,
                                     object: object,
                                     keyPathOrGet: .left("maximumDate"),
                                     values: Fixtures.datesAndNils)
        //      TODO: Investigate
        //      object.datePickerMode = .countDownTimer
        //      testEventStream(object.rp.countDownDuration,
        //               object: object,
        //               keyPathOrGetSet: .left("countDownDuration"),
        //               values: Fixtures.timeIntervalFixture)
        testEventStream(object.rp.minuteInterval,
                        object: object,
                        keyPathOrGetSet: .left("minuteInterval"),
                        values: Fixtures.ints)
      #endif
    }

    func testUISwitch() {
      #if os(iOS)
        let object = UISwitch()

        testEventStream(object.rp.isOn,
                        object: object,
                        keyPathOrGetSet: .left("on"),
                        values: Fixtures.bools)
        testOptionalEventStream(object.rp.onTintColor,
                                object: object,
                                keyPathOrGetSet: .left("onTintColor"),
                                values: Fixtures.colorsAndNils)
        testOptionalEventStream(object.rp.thumbTintColor,
                                object: object,
                                keyPathOrGetSet: .left("thumbTintColor"),
                                values: Fixtures.colorsAndNils)
        testOptionalEventStream(object.rp.onImage,
                                object: object,
                                keyPathOrGetSet: .left("onImage"),
                                values: Fixtures.imagesAndNils)
        testOptionalEventStream(object.rp.offImage,
                                object: object,
                                keyPathOrGetSet: .left("offImage"),
                                values: Fixtures.imagesAndNils)
      #endif
    }

    func testUIStepper() {
      #if os(iOS)
        let object = UIStepper()

        testEventStream(object.rp.isContinuous, object: object,
                        keyPathOrGetSet: .left("continuous"),
                        values: Fixtures.bools)
        testEventStream(object.rp.autorepeat, object: object,
                        keyPathOrGetSet: .left("autorepeat"),
                        values: Fixtures.bools)
        testEventStream(object.rp.wraps, object: object,
                        keyPathOrGetSet: .left("wraps"),
                        values: Fixtures.bools)
        testEventStream(object.rp.value, object: object,
                        keyPathOrGetSet: .left("value"),
                        values: Fixtures.doubles)
        testEventStream(object.rp.minimumValue, object: object,
                        keyPathOrGetSet: .left("minimumValue"),
                        values: Fixtures.doubles)
        testEventStream(object.rp.maximumValue, object: object,
                        keyPathOrGetSet: .left("maximumValue"),
                        values: Fixtures.doubles.map { $0 + 100.0 })
        testEventStream(object.rp.stepValue, object: object,
                        keyPathOrGetSet: .left("stepValue"),
                        values: Fixtures.doubles.map { $0 + 0.1 })
        for state in Fixtures.uiControlStates {
          let object = UIStepper()

          //    TODO: investigate
          //          testEventDestination(object.rp.backgroundImage(for: state), object: object,
          //                               keyPathOrGet: .right({ $0.backgroundImage(for: state) }),
          //                               values: testImages)
          testOptionalEventDestination(object.rp.incrementImage(for: state), object: object,
                                       keyPathOrGet: .right({ $0.incrementImage(for: state) }),
                                       values: Fixtures.images)
          testOptionalEventDestination(object.rp.dividerImage(forLeftSegmentState: state, rightSegmentState: state),
                                       object: object,
                                       keyPathOrGet:
            .right { $0.dividerImage(forLeftSegmentState: state, rightSegmentState: state) },
                                       values: Fixtures.images)
          testOptionalEventDestination(object.rp.decrementImage(for: state), object: object,
                                       keyPathOrGet: .right({ $0.decrementImage(for: state) }),
                                       values: Fixtures.images)
        }
      #endif
    }

    #if os(iOS)
    func _testUISlider(_ object: UISlider, state: UIControlState) {
      testOptionalEventDestination(object.rp.thumbImage(for: state), object: object,
                                   keyPathOrGet: .right({ $0.thumbImage(for: state) }),
                                   values: Fixtures.imagesAndNils)
      testOptionalEventDestination(object.rp.minimumTrackImage(for: state), object: object,
                                   keyPathOrGet: .right({ $0.minimumTrackImage(for: state) }),
                                   values: Fixtures.imagesAndNils)
      testOptionalEventDestination(object.rp.maximumTrackImage(for: state), object: object,
                                   keyPathOrGet: .right({ $0.maximumTrackImage(for: state) }),
                                   values: Fixtures.imagesAndNils)
    }
    #endif

    func testUISlider() {
      #if os(iOS)
        let object = UISlider()

        testEventStream(object.rp.value, object: object,
                        keyPathOrGetSet: .left("value"),
                        values: Fixtures.floats)
        testEventStream(object.rp.minimumValue, object: object,
                        keyPathOrGetSet: .left("minimumValue"),
                        values: Fixtures.floats)
        testEventStream(object.rp.minimumValue, object: object,
                        keyPathOrGetSet: .left("minimumValue"),
                        values: Fixtures.floats)
        testOptionalEventStream(object.rp.minimumValueImage, object: object,
                                keyPathOrGetSet: .left("minimumValueImage"),
                                values: Fixtures.imagesAndNils)
        testOptionalEventStream(object.rp.maximumValueImage, object: object,
                                keyPathOrGetSet: .left("maximumValueImage"),
                                values: Fixtures.imagesAndNils)
        testEventStream(object.rp.isContinuous, object: object,
                        keyPathOrGetSet: .left("continuous"),
                        values: Fixtures.bools)
        testOptionalEventStream(object.rp.minimumTrackTintColor, object: object,
                                keyPathOrGetSet: .left("minimumTrackTintColor"),
                                values: Fixtures.colorsAndNils)
        testOptionalEventStream(object.rp.maximumTrackTintColor, object: object,
                                keyPathOrGetSet: .left("maximumTrackTintColor"),
                                values: Fixtures.colorsAndNils)
        testOptionalEventStream(object.rp.thumbTintColor, object: object,
                                keyPathOrGetSet: .left("thumbTintColor"),
                                values: Fixtures.colorsAndNils)
        for state in Fixtures.uiControlStates {
          _testUISlider(UISlider(), state: state)
        }
      #endif
    }

    func testUIViewController() {
      let object = UIViewController()
      testOptionalEventStream(object.rp.title,
                              object: object,
                              keyPathOrGetSet: .left("title"),
                              values: Fixtures.stringsAndNils)
    }
  }

  // MARK: - T: Equatable
  extension iOSTests {
    func testEventStream<T: EventDestination&EventSource, Object: NSObject>(
      _ stream: T,
      object: Object,
      keyPathOrGetSet: Either<String, (getter: (Object) -> T.Update?, setter: (Object, T.Update?) -> Void)>,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line
      ) where T.Update: Equatable {
      testEventDestination(stream, object: object, keyPathOrGet: keyPathOrGetSet.mapRight { $0.getter },
                           values: values, file: file, line: line)
      testEventSource(stream, object: object, keyPathOrSet: keyPathOrGetSet.mapRight { $0.setter },
                      values: values, file: file, line: line)
    }

    func testEventDestination<T: EventDestination, Object: NSObject>(
      _ EventDestination: T,
      object: Object,
      keyPathOrGet: Either<String, (Object) -> T.Update?>,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line
      ) where T.Update: Equatable {
      for value in values {
        EventDestination.update(value, from: .main)
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
    func testOptionalEventStream<T: EventDestination&EventSource, Object: NSObject>(
      _ stream: T,
      object: Object,
      keyPathOrGetSet: Either<String, (getter: (Object) -> T.Update?, setter: (Object, T.Update?) -> Void)>,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line
      ) where T.Update: AsyncNinjaOptionalAdaptor,
      T.Update.AsyncNinjaWrapped: Equatable {
        testOptionalEventDestination(stream,
                                     object: object,
                                     keyPathOrGet: keyPathOrGetSet.mapRight { $0.getter },
                                     values: values,
                                     file: file,
                                     line: line)
        testOptionalEventSource(stream,
                                object: object,
                                keyPathOrSet: keyPathOrGetSet.mapRight { $0.setter },
                                values: values,
                                file: file,
                                line: line)
    }

    func testOptionalEventDestination<T: EventDestination, Object: NSObject>(
      _ EventDestination: T,
      object: Object,
      keyPathOrGet: Either<String, (Object) -> T.Update?>,
      values: [T.Update],
      file: StaticString = #file,
      line: UInt = #line,
      customGetter: ((Object) -> T.Update?)? = nil
      ) where T.Update: AsyncNinjaOptionalAdaptor,
      T.Update.AsyncNinjaWrapped: Equatable {
        for value in values {
          EventDestination.update(value, from: .main)
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

    func testOptionalEventSource<T: EventSource, Object: NSObject>(
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

#endif
