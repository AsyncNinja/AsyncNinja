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
  func startWith(_ update: Update, executor: Executor = Executor.default) -> Channel<Update, Success> {
    return startWith([update], executor: executor)
  }

  func startWith(_ updates: [Update], executor: Executor = Executor.default) -> Channel<Update, Success> {
    return producer(executor: executor) { producer in
      updates.forEach { producer.update($0, from: executor) }
      self.bindEvents(producer)
    }
  }

  func withLatest<ES: EventSource>(from source: ES) -> Channel<(Update, ES.Update), Void> {
    let locking = makeLocking(isFair: true)
    let producer = Producer<(Update, ES.Update), Void>()
    var myUpdate: Update?
    var otherUpdate: ES.Update?

    source.onUpdate { upd in
      locking.lock()
        if otherUpdate == nil && myUpdate == nil {
          if let myUpdate = myUpdate {
            producer.update((myUpdate, upd))
          }
        }
      otherUpdate = upd
      locking.unlock()
      }
      .onFailure { producer.fail($0) }
      .onSuccess { _ in producer.succeed() }

    let handler = self.makeHandler(executor: .default) { (event, _) in
      switch event {

      case let .update(upd):
        locking.lock()
        myUpdate = upd
        if let updOther = otherUpdate {
          producer.update((upd, updOther))
        }
        locking.unlock()
      case .completion:
        locking.lock()
        producer.succeed()
        locking.unlock()
      }
    }
    self._asyncNinja_retainHandlerUntilFinalization(handler)

    return producer
  }
}
