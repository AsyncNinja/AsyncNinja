//
//  Copyright (c) 2016-2019 Anton Mironov
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

#if os(macOS) || os(iOS) || os(tvOS)

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

import Dispatch
import Foundation

enum Fixtures {

  static let ints: [Int] = [1, 1, 2, 2, 3, 1, 4]
  static let timeIntervals: [TimeInterval] = [2, 2, 4, 8, 8, 16, 16]
  static let cgFloats: [CGFloat] = [0.0, 0.0, 0.25, 0.5, 0.5, 1.0, 1.0]
  static let floats: [Float] = [0.0, 0.0, 0.25, 0.5, 0.5, 1.0, 1.0]
  static let doubles: [Double] = [0.0, 0.0, 0.25, 0.5, 0.5, 1.0, 1.0]
  static let bools: [Bool] = [true, true, false, false, true]
  static let stringsAndNils: [String?] = ["1", nil, "1", "1", "2", "2", nil, nil, "3", "1", "4"]
  static let strings: [String] = Fixtures.stringsAndNils.compactMap { $0 }
  #if os(iOS) || os(tvOS)
  static let attributedStrings = Fixtures.strings
    .map { NSAttributedString(string: $0,
                              attributes: [
                                NSAttributedString.Key.font: UIFont.systemFont(ofSize: 14.0)
      ])
  }
  #elseif os(macOS)
  static let attributedStrings = Fixtures.strings
    .map { NSAttributedString(string: $0,
                              attributes: [
                                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 14.0)
      ])
  }
  #endif

  static let textAlignements: [NSTextAlignment]
    = [.center, .left, .left, .center, .right, .right, .natural, .natural]
  static let lineBreakModes: [NSLineBreakMode] = [
    .byWordWrapping, .byWordWrapping, .byCharWrapping,
    .byCharWrapping, .byClipping, .byTruncatingHead,
    .byWordWrapping, .byTruncatingMiddle, .byTruncatingTail
  ]
  static let locales: [Locale] = [
    Locale(identifier: "uk"),
    Locale(identifier: "uk"),
    Locale(identifier: "nl"),
    Locale(identifier: "nl"),
    Locale(identifier: "en_US"),
    Locale(identifier: "nl")
  ]
  static let calendars: [Calendar] = [
    Calendar.current,
    Calendar.current,
    Calendar(identifier: .iso8601),
    Calendar(identifier: .japanese),
    Calendar.current
  ]
  static let timezonesAndNils: [TimeZone?] = [
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

  static let datesAndNils: [Date?] = [
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
  static let dates: [Date] = Fixtures.datesAndNils.compactMap { $0 }
  static let shadowOffsets: [CGSize] = [
    CGSize(width: 0, height: 0),
    CGSize(width: 0, height: 0),
    CGSize(width: 2, height: 3),
    CGSize(width: 2, height: 3),
    CGSize(width: -2, height: -3),
    CGSize(width: 2, height: 3),
    CGSize(width: 0, height: 0)
  ]
}
#endif

#if os(iOS) || os(tvOS)
import UIKit

extension Fixtures {
  static let colorsAndNils: [UIColor?]
    = [.white, .white, nil, .red, nil, nil, .green, nil, .green, .blue, .blue]
  static let colors: [UIColor] = Fixtures.colorsAndNils.compactMap { $0 }
  static let fontTextStyles: [UIFont.TextStyle]
    = [.headline, .subheadline, .body, .footnote, .caption1, .caption2]
  static let fonts: [UIFont] = Fixtures.fontTextStyles
    .map(UIFont.preferredFont(forTextStyle:))
  static let baselineAdjustments: [UIBaselineAdjustment]
    = [.alignBaselines, .alignBaselines, .alignCenters, .alignCenters, .none, .alignBaselines, .alignCenters]

  static func drawTestImage(_ text: String, width: CGFloat = 100, height: CGFloat = 100) -> UIImage {
    return UIImage.draw(size: CGSize(width: width, height: height)) { _ in
      text.draw(at: CGPoint(x: 0, y: 0), withAttributes: [:])
    }
  }

  static let imageOne = drawTestImage("1")
  static let imageTwo = drawTestImage("2")
  static let imageThree = drawTestImage("3")
  static let imageFour = drawTestImage("4")
  static let imagesAndNils: [UIImage?] = [imageOne, nil, imageOne,
                                          imageOne, imageTwo, imageTwo,
                                          nil, nil, imageThree,
                                          imageOne, imageFour]
  static let images: [UIImage] = Fixtures.imagesAndNils.compactMap { $0 }
  static let arraysOfImagesAndNils: [[UIImage]?] = Fixtures.imagesAndNils
    .map { $0.map { [$0] } }
  static let uiControlStates: [UIControl.State] = eval {
    var result: [UIControl.State] = [.normal, .highlighted, .disabled, .selected]
    if #available(iOS 9.0, *) {
      result.append(.focused)
    }
    return result
  }
}

private extension UIImage {
  class func draw(size: CGSize, opaque: Bool = false, scale: CGFloat = 0.0, drawer: (CGContext) -> Void) -> UIImage {
    UIGraphicsBeginImageContextWithOptions(size, opaque, scale)
    defer { UIGraphicsEndImageContext(); }
    drawer(UIGraphicsGetCurrentContext()!)
    return UIGraphicsGetImageFromCurrentImageContext()!
  }
}
#endif
