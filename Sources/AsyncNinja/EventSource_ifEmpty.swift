//
//  Copyright (c) 2016-2020 Anton Mironov, Loki
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

public extension EventSource {
  func ifEmpty<Source: EventSource>(switchTo other: Source) -> Channel<Update,Success>
    where Source.Update == Update, Source.Success == Success {
      
      let producer = Producer<Self.Update,Self.Success>(bufferSize: Swift.max(bufferSize, other.bufferSize))
      let locking = makeLocking(isFair: true)
      var updateCounter = 0
      
      let handler = self.makeHandler(executor: .immediate) { event, executor in
        switch event {
        case .update(let upd):
          locking.lock()
          updateCounter += 1
          locking.unlock()
          
          producer.update(upd, from: executor)
        case .completion(let comp):
          locking.lock()
          let shouldSwitch = updateCounter > 0
          locking.unlock()
          
          if shouldSwitch {
            producer.complete(comp, from: executor)
          } else {
            other.bindEvents(producer)
          }
        }
      }
      
      _asyncNinja_retainHandlerUntilFinalization(handler)
      
      return producer
  }
}
