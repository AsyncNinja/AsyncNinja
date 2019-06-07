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

public extension EventSource {
    
    /// Picks latest update value of the channel every interval and sends it
    ///
    /// - Parameters:
    ///   - deadline: to start picking peridic values after
    ///   - interval: interfal for picking latest update values
    ///   - leeway: leeway for timer
    ///   - cancellationToken: `CancellationToken` to use.
    ///     Keep default value of the argument unless you need
    ///     an extended cancellation options of returned primitive
    ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
    ///     Keep default value of the argument unless you need
    /// - Returns: channel
    func throttle(
        interval: Double,
        qos: DispatchQoS.QoSClass = .default,
        cancellationToken: CancellationToken? = nil,
        bufferSize: DerivedChannelBufferSize = .default
        ) -> Channel<Update, Success> {
        // Test: EventSource_TransformTests.testDebounce
        
        typealias Destination = Producer<Update, Success>
        let producer = Destination(bufferSize: bufferSize.bufferSize(self))
        cancellationToken?.add(cancellable: producer)
        
        let helper = ThrottleEventSourceHelper<Self, Destination>(
            destination: producer,
            interval: interval,
            qos: qos)
        
        producer._asyncNinja_retainHandlerUntilFinalization(helper.eventHandler(source: self))
        
        return producer
    }
}

private class ThrottleEventSourceHelper<Source: EventSource, Destination: EventDestination>
where Source.Update == Destination.Update, Source.Success == Destination.Success {
    var locking = makeLocking()
    var nextUpdate : Source.Update?
    let queue: DispatchQueue
    var timer: DispatchSourceTimer?
    var timerInterval: DispatchTimeInterval
    weak var destination: Destination?
    
    init(
        destination: Destination,
        interval: Double,
        qos: DispatchQoS.QoSClass
        ) {
        
        self.destination = destination
        self.timerInterval = interval.dispatchInterval
        self.queue = DispatchQueue.global(qos: qos)
    }
    
    func eventHandler(source: Source) -> AnyObject? {
        return source.makeHandler(executor: .immediate) { (event, originalExecutor) in
            
            self.locking.lock()
            defer { self.locking.unlock() }
            
            switch event {
            case let .completion(completion):
                if let update = self.nextUpdate {
                    self.sendNow(update: update)
                }
                self.destination?.complete(completion, from: originalExecutor)
                
            case let .update(update):
                if self.timer == nil {
                    self.sendNow(update: update)
                    self.createTimer()
                } else {
                    if self.nextUpdate == nil {
                        self.nextUpdate = update
                    }
                }
            }
        }
    }
    
    private func sendNow(update: Destination.Update) {
        self.nextUpdate = nil
        self.destination?.update(update)
    }
    
    private func createTimer() {
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer!.schedule(deadline: DispatchTime.now() + timerInterval)
        timer!.setEventHandler {
            if let update = self.nextUpdate {
                self.sendNow(update: update)
            }
            self.timer = nil
        }
        timer!.resume()
    }
}

public extension Double {
    var dispatchInterval: DispatchTimeInterval {
        let microseconds = Int64(self * 1000000) // perhaps use nanoseconds, though would more often be > Int.max
        return microseconds < Int.max ? DispatchTimeInterval.microseconds(Int(microseconds)) : DispatchTimeInterval.seconds(Int(self))
    }
}
