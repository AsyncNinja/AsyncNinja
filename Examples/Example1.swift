//
//  Copyright (c) 2016 Anton Mironov
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

import Foundation
import AppKit
import FunctionalConcurrency

struct Config {
  var logoURL : URL

  init(json: AnyObject) throws {
    let jsonObject = (json as! [String:AnyObject])
    self.logoURL = URL(string: jsonObject["imageURL"] as! String)!
  }

}

func readConfig(from url: URL) throws -> Config {
  let data = try Data(contentsOf: url)
  let json = try JSONSerialization.jsonObject(with: data, options: [])
  return try Config(json: json)
}

func dowloadImage(from url: URL) -> Future<Failable<Image>> {
  fatalError() // TODO
}

func fetchLogo() -> Future<Image> {
  let configURL = URL(fileURLWithPath: "~/config.json")
  return future(executor: .utility) { (try readConfig(from: configURL)).logoURL }
    .liftSuccess(executor: .background, block: dowloadImage)
    .liftFailure(executor: .background) { Image(named: "old_logo.png")! }
}
