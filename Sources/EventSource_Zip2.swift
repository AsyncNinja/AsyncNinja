//
//  Copyright (c) 2017 Anton Mironov
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

/// Zips two channels into channels of tuples
public func zip<LeftSource: EventSource, RightSource: EventSource>(
  _ leftSource: LeftSource,
  _ rightSource: RightSource,
  cancellationToken: CancellationToken? = nil,
  bufferSize: DerivedChannelBufferSize = .default
  ) -> Channel<(LeftSource.Update, RightSource.Update), (LeftSource.Success, RightSource.Success)> {
  // Test: EventSource_Zip2Tests.testZip
  typealias DestinationUpdate = (LeftSource.Update, RightSource.Update)
  typealias DestinationSuccess = (LeftSource.Success, RightSource.Success)
  typealias Destination = Producer<DestinationUpdate, DestinationSuccess>

  let producer = Destination(bufferSize: bufferSize.bufferSize(leftSource, rightSource))
  cancellationToken?.add(cancellable: producer)

  let helper = Zip2EventSourcesHelper<LeftSource, RightSource, Destination>(destination: producer)
  producer._asyncNinja_retainHandlerUntilFinalization(helper.makeHandler(leftSource: leftSource))
  producer._asyncNinja_retainHandlerUntilFinalization(helper.makeHandler(rightSource: rightSource))

  return producer
}

/// **internal use only**
/// Encapsulates merging behavior
private class Zip2EventSourcesHelper<LeftSource: EventSource, RightSource: EventSource, Destination: EventDestination>
  where Destination.Update == (LeftSource.Update, RightSource.Update),
        Destination.Success == (LeftSource.Success, RightSource.Success) {

  var locking = makeLocking()
  var queueOfUpdates = Queue<Either<LeftSource.Update, RightSource.Update>>()
  var leftSuccess: LeftSource.Success?
  var rightSuccess: RightSource.Success?
  weak var destination: Destination?

  init(destination: Destination) {
    self.destination = destination
  }

  func makeHandlerBlock<Update, Success>(
    updateHandler: @escaping (Update) -> (LeftSource.Update, RightSource.Update)?,
    successHandler: @escaping (Success) -> (LeftSource.Success, RightSource.Success)?
    ) -> (_ event: ChannelEvent<Update, Success>, _ originalExecutor: Executor) -> Void {
    return { (event, originalExecutor) in
      switch event {
      case let .update(update):
        self.locking.lock()
        defer { self.locking.unlock() }
        if let updateAB = updateHandler(update) {
          self.destination?.update(updateAB, from: originalExecutor)
        }
      case let .completion(.failure(error)):
        self.destination?.fail(error, from: originalExecutor)
      case let .completion(.success(localSuccess)):
        self.locking.lock()
        defer { self.locking.unlock() }
        if let success = successHandler(localSuccess) {
          self.destination?.succeed(success, from: originalExecutor)
        }
      }
    }
  }

  func makeHandler(leftSource: LeftSource) -> AnyObject? {
    func updateHandler(update: LeftSource.Update) -> (LeftSource.Update, RightSource.Update)? {
      if let rightUpdate = queueOfUpdates.first?.right {
        _ = self.queueOfUpdates.pop()
        return (update, rightUpdate)
      } else {
        self.queueOfUpdates.push(.left(update))
        return nil
      }
    }

    func successHandler(success: LeftSource.Success) -> (LeftSource.Success, RightSource.Success)? {
      self.leftSuccess = success
      return self.rightSuccess.map { (success, $0) }
    }

    let handlerBlock = makeHandlerBlock(updateHandler: updateHandler, successHandler: successHandler)
    return leftSource.makeHandler(executor: .immediate, handlerBlock)
  }

  func makeHandler(rightSource: RightSource) -> AnyObject? {
    func updateHandler(update: RightSource.Update) -> (LeftSource.Update, RightSource.Update)? {
      if let leftUpdate = queueOfUpdates.first?.left {
        _ = self.queueOfUpdates.pop()
        return (leftUpdate, update)
      } else {
        self.queueOfUpdates.push(.right(update))
        return nil
      }
    }

    func successHandler(success: RightSource.Success) -> (LeftSource.Success, RightSource.Success)? {
      self.rightSuccess = success
      return self.leftSuccess.map { ($0, success) }
    }

    let handlerBlock = makeHandlerBlock(updateHandler: updateHandler, successHandler: successHandler)
    return rightSource.makeHandler(executor: .immediate, handlerBlock)
  }
}
