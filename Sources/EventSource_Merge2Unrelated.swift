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

import Dispatch

/// Merges channels with completely unrelated types into one
public func merge<LeftSource: EventSource, RightSource: EventSource>(
  _ leftSource: LeftSource,
  _ rightSource: RightSource,
  cancellationToken: CancellationToken? = nil,
  bufferSize: DerivedChannelBufferSize = .default
  ) -> Channel<Either<LeftSource.Update, RightSource.Update>, (LeftSource.Success, RightSource.Success)> {

  // Test: EventSource_Merge2Tests.testMergeIntsAndStrings

  typealias DestinationUpdate = Either<LeftSource.Update, RightSource.Update>
  typealias ResultungSuccess = (LeftSource.Success, RightSource.Success)
  typealias Destination = Producer<DestinationUpdate, ResultungSuccess>
  let producer = Destination(bufferSize: bufferSize.bufferSize(leftSource, rightSource))
  cancellationToken?.add(cancellable: producer)

  let helper = Merge2UnrelatesEventSourcesHelper<LeftSource, RightSource, Destination>(destination: producer)
  producer._asyncNinja_retainHandlerUntilFinalization(helper.makeHandler(leftSource: leftSource))
  producer._asyncNinja_retainHandlerUntilFinalization(helper.makeHandler(rightSource: rightSource))
  return producer
}

/// **internal use only**
/// Encapsulates merging behavior
private class Merge2UnrelatesEventSourcesHelper<
  LeftSource: EventSource, RightSource: EventSource, Destination: EventDestination> where
Destination.Update == Either<LeftSource.Update, RightSource.Update>,
Destination.Success == (LeftSource.Success, RightSource.Success) {
  var locking = makeLocking()
  var leftSuccess: LeftSource.Success?
  var rightSuccess: RightSource.Success?
  weak var destination: Destination?

  init(destination: Destination) {
    self.destination = destination
  }

  func makeHandlerBlock<Update, Success>(
    updateHandler: @escaping (_ update: Update, _ originalExecutor: Executor) -> Void,
    successHandler: @escaping (_ success: Success) -> (LeftSource.Success, RightSource.Success)?
    ) -> (_ event: ChannelEvent<Update, Success>, _ originalExecutor: Executor) -> Void {

    // `self` is being captured but it is okay
    // because it does not retain valuable resources

    return {
      (event, originalExecutor) in
      switch event {
      case let .update(update):
        updateHandler(update, originalExecutor)
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
    func handleUpdate(update: LeftSource.Update, originalExecutor: Executor) {
      self.destination?.update(.left(update), from: originalExecutor)
    }

    let handlerBlock = makeHandlerBlock(updateHandler: handleUpdate) { (success: LeftSource.Success) in
      self.leftSuccess = success
      return self.rightSuccess.map { (success, $0) }
    }

    return leftSource.makeHandler(executor: .immediate, handlerBlock)
  }

  func makeHandler(rightSource: RightSource) -> AnyObject? {
    func handleUpdate(update: RightSource.Update, originalExecutor: Executor) {
      self.destination?.update(.right(update), from: originalExecutor)
    }

    let handlerBlock = makeHandlerBlock(updateHandler: handleUpdate) { (success: RightSource.Success) in
      self.rightSuccess = success
      return self.leftSuccess.map { ($0, success) }
    }

    return rightSource.makeHandler(executor: .immediate, handlerBlock)
  }
}
