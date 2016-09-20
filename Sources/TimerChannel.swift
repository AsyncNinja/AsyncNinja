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

private func makeTimer(dispatchTimer: DispatchSourceTimer) -> Channel<Void> {
  let producer = Producer<Void>()
  dispatchTimer.setEventHandler { [weak producer] in
    producer?.send(())
  }
  dispatchTimer.resume()
  producer.insertToReleasePool(dispatchTimer)
  return producer
}

public func makeTimer(interval: DispatchTimeInterval) -> Channel<Void> {
  return makeTimer(deadline: DispatchTime.now(), interval: interval)
}

public func makeTimer(interval: DispatchTimeInterval, leeway: DispatchTimeInterval) -> Channel<Void> {
  return makeTimer(deadline: DispatchTime.now(), interval: interval, leeway: leeway)
}

public func makeTimer(deadline: DispatchTime, interval: DispatchTimeInterval) -> Channel<Void> {
  let timer = DispatchSource.makeTimerSource()
  timer.scheduleRepeating(deadline: deadline, interval: interval)
  return makeTimer(dispatchTimer: timer)
}

public func makeTimer(deadline: DispatchTime, interval: DispatchTimeInterval, leeway: DispatchTimeInterval) -> Channel<Void> {
  let timer = DispatchSource.makeTimerSource()
  timer.scheduleRepeating(deadline: deadline, interval: interval, leeway: leeway)
  return makeTimer(dispatchTimer: timer)
}

public func makeTimer(wallDeadline: DispatchWallTime, interval: DispatchTimeInterval) -> Channel<Void> {
  let timer = DispatchSource.makeTimerSource()
  timer.scheduleRepeating(wallDeadline: wallDeadline, interval: interval)
  return makeTimer(dispatchTimer: timer)
}

public func makeTimer(wallDeadline: DispatchWallTime, interval: DispatchTimeInterval, leeway: DispatchTimeInterval) -> Channel<Void> {
  let timer = DispatchSource.makeTimerSource()
  timer.scheduleRepeating(wallDeadline: wallDeadline, interval: interval, leeway: leeway)
  return makeTimer(dispatchTimer: timer)
}

//

public func makeTimer(interval: Double) -> Channel<Void> {
  return makeTimer(deadline: DispatchTime.now(), interval: interval)
}

public func makeTimer(interval: Double, leeway: DispatchTimeInterval) -> Channel<Void> {
  return makeTimer(deadline: DispatchTime.now(), interval: interval, leeway: leeway)
}

public func makeTimer(deadline: DispatchTime, interval: Double) -> Channel<Void> {
  let timer = DispatchSource.makeTimerSource()
  timer.scheduleRepeating(deadline: deadline, interval: interval)
  return makeTimer(dispatchTimer: timer)
}

public func makeTimer(deadline: DispatchTime, interval: Double, leeway: DispatchTimeInterval) -> Channel<Void> {
  let timer = DispatchSource.makeTimerSource()
  timer.scheduleRepeating(deadline: deadline, interval: interval, leeway: leeway)
  return makeTimer(dispatchTimer: timer)
}

public func makeTimer(wallDeadline: DispatchWallTime, interval: Double) -> Channel<Void> {
  let timer = DispatchSource.makeTimerSource()
  timer.scheduleRepeating(wallDeadline: wallDeadline, interval: interval)
  return makeTimer(dispatchTimer: timer)
}

public func makeTimer(wallDeadline: DispatchWallTime, interval: Double, leeway: DispatchTimeInterval) -> Channel<Void> {
  let timer = DispatchSource.makeTimerSource()
  timer.scheduleRepeating(wallDeadline: wallDeadline, interval: interval, leeway: leeway)
  return makeTimer(dispatchTimer: timer)
}
