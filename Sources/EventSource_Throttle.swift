//
//  Copyright (c) 2019 Sergiy Vynnychenko
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

public enum AfterThrottling {
  case sendLast
  case sendFirst
  case none
}
 
public struct ThrottleOptions {
  let qos:                DispatchQoS.QoSClass
  let cancellationToken:  CancellationToken?
  let bufferSize:         DerivedChannelBufferSize

  /// - parameter qos: quality of service.
  /// - parameter cancellationToken: `CancellationToken` to use. Keep default value of the argument unless you need an extended cancellation options of returned primitive
  /// - parameter bufferSize: `DerivedChannelBufferSize` of derived channel. Keep default value of the argument unless you need
  public init(qos: DispatchQoS.QoSClass = .default,
              cancellationToken: CancellationToken? = nil,
              bufferSize: DerivedChannelBufferSize = .default) {
    self.qos = qos
    self.cancellationToken = cancellationToken
    self.bufferSize = bufferSize
  }
}

public extension EventSource {
  
  /**
   Returns an Channel that emits the first and the latest item emitted by the EventSource during interval.
   
   This operator makes sure that no two or more elements are emitted within specified interval.
   
   - parameter interval: Throttling duration for each update.
   - parameter options: quality of service, cancellationToken and bufferSize
   - returns: The throttled Channel.
   */
  func throttle(
    interval: Double,
    after: AfterThrottling = .sendLast,
    options: ThrottleOptions = ThrottleOptions()
    ) -> Channel<Update, Success> {
    // Test: EventSource_TransformTests.testTrottle
    
    typealias Destination = Producer<Update, Success>
    let producer = Destination(bufferSize: options.bufferSize.bufferSize(self))
    options.cancellationToken?.add(cancellable: producer)
    
    let helper = ThrottleEventSourceHelper<Self, Destination>(destination: producer, interval: interval, qos: options.qos, after: after)
    
    producer._asyncNinja_retainHandlerUntilFinalization(helper.eventHandler(source: self))
    
    return producer
  }
}

private class ThrottleEventSourceHelper<Source: EventSource, Destination: EventDestination>
where Source.Update == Destination.Update, Source.Success == Destination.Success {
  var locking = makeLocking()
  let after: AfterThrottling
  var nextUpdate : Source.Update?
  let queue: DispatchQueue
  var timer: DispatchSourceTimer?
  var timerInterval: DispatchTimeInterval
  weak var destination: Destination?
  
  init(
    destination: Destination,
    interval: Double,
    qos: DispatchQoS.QoSClass,
    after: AfterThrottling
    ) {
    
    self.destination = destination
    self.timerInterval = interval.dispatchInterval
    self.queue = DispatchQueue.global(qos: qos)
    self.after = after
  }
  
  func eventHandler(source: Source) -> AnyObject? {
    return source.makeHandler(executor: .immediate) { (event, originalExecutor) in
      
      self.locking.lock()
      defer { self.locking.unlock() }
      
      switch event {
      case let .completion(completion):   self.onComplete(completion: completion, executor: originalExecutor)
      case let .update(update):           self.onUpdate(update: update)
      }
    }
  }
  
  func onUpdate(update: Destination.Update) {
    if timer == nil {
      sendNow(update: update)
      createTimer()
    } else {
      
      // decide which update to send
      // after throttling interval
      switch after {
      case .sendLast:     nextUpdate = update
      case .sendFirst:    if nextUpdate == nil { nextUpdate = update }
      case .none:         break
      }
      
    }
  }
  
  func onComplete(completion: Fallible<Source.Success>, executor: Executor) {
    if let update = nextUpdate {
      self.sendNow(update: update)
    }
    self.destination?.complete(completion, from: executor)
  }
}

extension ThrottleEventSourceHelper {
  private func sendNow(update: Destination.Update) {
    nextUpdate = nil
    destination?.update(update)
  }
  
  private func createTimer() {
    timer = DispatchSource.makeTimerSource(queue: queue)
    timer!.schedule(deadline: DispatchTime.now() + timerInterval)
    timer!.setEventHandler { self.timerHandler() }
    timer!.resume()
  }
  
  private func timerHandler() {
    if let update = nextUpdate {
      sendNow(update: update)
      createTimer()
    } else {
      timer = nil
    }
  }
}

public extension Double {
  var dispatchInterval: DispatchTimeInterval {
    let microseconds = Int64(self * 1000000) // perhaps use nanoseconds, though would more often be > Int.max
    return microseconds < Int.max ? DispatchTimeInterval.microseconds(Int(microseconds)) : DispatchTimeInterval.seconds(Int(self))
  }
}
