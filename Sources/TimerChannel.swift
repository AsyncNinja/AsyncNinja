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

public typealias TimerChannel = Channel<Void, Void>

private func makeTimer(dispatchTimer: DispatchSourceTimer,
                       executor: Executor,
                       from originalExecutor: Executor) -> TimerChannel {
  let producer = Producer<Void, Void>()
  dispatchTimer.setEventHandler { [weak producer] in
    if case .some = executor.representedDispatchQueue {
      producer?.update((), from: originalExecutor)
    } else {
      executor.execute(from: originalExecutor) { (originalExecutor) in
        producer?.update((), from: originalExecutor)
      }
    }
  }
  dispatchTimer.resume()
  producer._asyncNinja_retainUntilFinalization(dispatchTimer)
  return producer
}

/// Makes channel that will receive updates after a *deadline*,
/// in an *interval* (in seconds), with a *leeway*
public func makeTimer(
  interval: DispatchTimeInterval,
  executor: Executor = .primary) -> TimerChannel {
  return makeTimer(deadline: DispatchTime.now(), interval: interval, executor: executor)
}

/// Makes channel that will receive updates after a *deadline*,
/// in an *interval* (in seconds), with a *leeway*
public func makeTimer(
  interval: DispatchTimeInterval,
  leeway: DispatchTimeInterval,
  executor: Executor = .primary) -> TimerChannel {
  return makeTimer(deadline: DispatchTime.now(), interval: interval, leeway: leeway, executor: executor)
}

private func makeTimer(executor: Executor, setup: (DispatchSourceTimer) -> Void) -> TimerChannel {
  let queueExecutor = executor.dispatchQueueBasedExecutor
  let timer = DispatchSource.makeTimerSource(queue: queueExecutor.representedDispatchQueue!)
  setup(timer)
  return makeTimer(dispatchTimer: timer, executor: executor, from: queueExecutor)
}

/// Makes channel that will receive updates after a *deadline*,
/// in an *interval* (in seconds), with a *leeway*
public func makeTimer(deadline: DispatchTime,
                      interval: DispatchTimeInterval,
                      executor: Executor = .primary
                      ) -> TimerChannel {
  return makeTimer(executor: executor) {
    $0.scheduleRepeating(deadline: deadline, interval: interval)
  }
}

/// Makes channel that will receive updates after a *deadline*,
/// in an *interval* (in seconds), with a *leeway*
public func makeTimer(deadline: DispatchTime,
                      interval: DispatchTimeInterval,
                      leeway: DispatchTimeInterval,
                      executor: Executor = .primary
  ) -> TimerChannel {
  return makeTimer(executor: executor) {
    $0.scheduleRepeating(deadline: deadline, interval: interval, leeway: leeway)
  }
}

/// Makes channel that will receive updates after a *deadline*,
/// in an *interval* (in seconds), with a *leeway*
public func makeTimer(wallDeadline: DispatchWallTime,
                      interval: DispatchTimeInterval,
                      executor: Executor = .primary
  ) -> TimerChannel {
  return makeTimer(executor: executor) {
    $0.scheduleRepeating(wallDeadline: wallDeadline, interval: interval)
  }
}

/// Makes channel that will receive updates after a *deadline*,
/// in an *interval* (in seconds), with a *leeway*
public func makeTimer(wallDeadline: DispatchWallTime,
                      interval: DispatchTimeInterval,
                      leeway: DispatchTimeInterval,
                      executor: Executor = .primary
  ) -> TimerChannel {
  return makeTimer(executor: executor) {
    $0.scheduleRepeating(wallDeadline: wallDeadline, interval: interval, leeway: leeway)
  }
}

// MARK: -

/// Makes channel that will receive updates after a *deadline*,
/// in an *interval* (in seconds), with a *leeway*
public func makeTimer(interval: Double, executor: Executor = .primary) -> TimerChannel {
  return makeTimer(deadline: DispatchTime.now(), interval: interval, executor: executor)
}

/// Makes channel that will receive updates after a *deadline*,
/// in an *interval* (in seconds), with a *leeway*
public func makeTimer(interval: Double,
                      leeway: DispatchTimeInterval,
                      executor: Executor = .primary
  ) -> TimerChannel {
  return makeTimer(deadline: DispatchTime.now(), interval: interval, leeway: leeway, executor: executor)
}

/// Makes channel that will receive updates after a *deadline*,
/// in an *interval* (in seconds), with a *leeway*
public func makeTimer(deadline: DispatchTime,
                      interval: Double,
                      executor: Executor = .primary) -> TimerChannel {
  return makeTimer(executor: executor) {
    $0.scheduleRepeating(deadline: deadline, interval: interval)
  }
}

/// Makes channel that will receive updates after a *deadline*,
/// in an *interval* (in seconds), with a *leeway*
public func makeTimer(deadline: DispatchTime,
                      interval: Double,
                      leeway: DispatchTimeInterval,
                      executor: Executor = .primary) -> TimerChannel {
  return makeTimer(executor: executor) {
    $0.scheduleRepeating(deadline: deadline, interval: interval, leeway: leeway)
  }
}

/// Makes channel that will receive updates after a *deadline*,
/// in an *interval* (in seconds), with a *leeway*
public func makeTimer(wallDeadline: DispatchWallTime,
                      interval: Double,
                      executor: Executor = .primary) -> TimerChannel {
  return makeTimer(executor: executor) {
    $0.scheduleRepeating(wallDeadline: wallDeadline, interval: interval)
  }
}

/// Makes channel that will receive updates after a *deadline*,
/// in an *interval* (in seconds), with a *leeway*
public func makeTimer(wallDeadline: DispatchWallTime,
                      interval: Double,
                      leeway: DispatchTimeInterval,
                      executor: Executor = .primary) -> TimerChannel {
  return makeTimer(executor: executor) {
    $0.scheduleRepeating(wallDeadline: wallDeadline, interval: interval, leeway: leeway)
  }
}
