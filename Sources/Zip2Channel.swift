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

import Dispatch

//public func zip<T, U>(_ leftChannel: Channel<T>, _ rightChannel: Channel<U>) -> Channel<(T, U)> {
//  let resultChannel = Producer<(T, U)>()
//  let leftQueue = QueueImpl<T>()
//  let rightQueue = QueueImpl<U>()
//  var locking = makeLocking()
//
//  func makeElement(_ leftQueue: QueueImpl<T>, _ rightQueue: QueueImpl<U>) -> (T, U)? {
//    if leftQueue.isEmpty || rightQueue.isEmpty {
//      return nil
//    } else {
//      return (leftQueue.pop()!, rightQueue.pop()!)
//    }
//  }
//
//  let leftHandler = leftChannel.makePeriodicHandler(executor: .immediate) { [weak resultChannel] leftValue in
//    guard let resultChannel = resultChannel else { return }
//    locking.lock()
//    defer { locking.unlock() }
//    leftQueue.push(leftValue)
//    if let element = makeElement(leftQueue, rightQueue) {
//      resultChannel.send(element)
//    }
//  }
//  if let leftHandler = leftHandler {
//    resultChannel.insertToReleasePool(leftHandler)
//  }
//
//  let rightHandler = rightChannel.makePeriodicHandler(executor: .immediate) { [weak resultChannel] rightValue in
//    guard let resultChannel = resultChannel else { return }
//    locking.lock()
//    defer { locking.unlock() }
//    rightQueue.push(rightValue)
//    if let element = makeElement(leftQueue, rightQueue) {
//      resultChannel.send(element)
//    }
//  }
//
//  if let rightHandler = rightHandler {
//    resultChannel.insertToReleasePool(rightHandler)
//  }
//
//  return resultChannel
//}
