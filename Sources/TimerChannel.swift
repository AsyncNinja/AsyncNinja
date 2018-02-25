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

/// Specification of timer
public struct TimerSpec {

  /// timer start
  public var deadline: Deadline

  /// repeat interval
  public var interval: Interval

  /// timer leeway
  public var leeway: DispatchTimeInterval?

  /// cancelaltion token for the timer
  public var cancellationToken: CancellationToken?

  /// interval of events
  public enum Interval {

    /// Defines interval based on `DispatchTimeInterval`
    case dispatch(DispatchTimeInterval)

    /// Defines interval based on a number of seconds
    case seconds(Double)
  }

  /// timer start
  public enum Deadline {

    /// Defines deadline based on `DispatchWallTime`
    case walltime(DispatchWallTime)

    /// Defines deadline based on `DispatchTime`
    case time(DispatchTime)
  }

  /// Makes DispatchSourceTimer
  ///
  /// - Parameter queue: queue to handle events on
  /// - Returns: DispatchSourceTimer
  public func makeTimer(queue: DispatchQueue) -> DispatchSourceTimer {
    let timer = DispatchSource.makeTimerSource(queue: queue)
    switch deadline {
    case let .walltime(deadline):
      switch interval {
      case let .dispatch(interval):
        if let leeway = leeway {
          timer.schedule(wallDeadline: deadline, repeating: interval, leeway: leeway)
        } else {
          timer.schedule(wallDeadline: deadline, repeating: interval)
        }
      case let .seconds(interval):
        if let leeway = leeway {
          timer.schedule(wallDeadline: deadline, repeating: interval, leeway: leeway)
        } else {
          timer.schedule(wallDeadline: deadline, repeating: interval)
        }
      }
    case let .time(deadline):
      switch interval {
      case let .dispatch(interval):
        if let leeway = leeway {
          timer.schedule(deadline: deadline, repeating: interval, leeway: leeway)
        } else {
          timer.schedule(deadline: deadline, repeating: interval)
        }
      case let .seconds(interval):
        if let leeway = leeway {
          timer.schedule(deadline: deadline, repeating: interval, leeway: leeway)
        } else {
          timer.schedule(deadline: deadline, repeating: interval)
        }
      }
    }

    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
      cancellationToken?.notifyCancellation { [weak timer] in
        timer?.cancel()
      }
    #else
      // DispatchSourceTimer is not denoted as a class for some unknown reason
      cancellationToken?.notifyCancellation { timer.cancel() }
    #endif
    return timer
  }

  /// Makes channel that
  ///
  /// - Parameters:
  ///   - executor: to schedule timer on
  ///   - originalExecutor: `Executor` you calling this method on.
  ///   Specifying this argument will allow to perform syncronous
  ///   executions on `strictAsync: false` `Executor`s.
  ///   Use default value or nil if you are not sure about an `Executor`
  ///   you calling this method on.
  ///   - maker: block that will be called to produce update for `Channel`
  /// - Returns: `Channel`
  public func makeTimerChannel<T>(
    executor: Executor = .primary,
    _ maker: @escaping () throws -> T
    ) -> Channel<T, Void>
  {
    let producer = Producer<T, Void>()
    let queueExecutor = executor.dispatchQueueBasedExecutor
    let timer = makeTimer(queue: queueExecutor.representedDispatchQueue!)
    timer.setEventHandler { [weak producer] in
      if case .some = executor.representedDispatchQueue {
        guard case .some = producer else { return }
        do { producer?.update(try maker(), from: executor) } catch { producer?.fail(error) }
      } else {
        executor.execute(from: queueExecutor) { (originalExecutor) in
          guard case .some = producer else { return }
          do { producer?.update(try maker(), from: originalExecutor) } catch { producer?.fail(error) }
        }
      }
    }
    timer.resume()
    producer._asyncNinja_notifyFinalization {
      timer.cancel()
    }
    return producer
  }
}

/// Makes channel of provides updates periodically
///
/// - Parameters:
///   - interval: in an *interval* (in seconds)
///   - executor: executor to
/// - Returns: channel
public func makeTimer(
  executor: Executor = .primary,
  interval: Double,
  cancellationToken: CancellationToken? = nil
  ) -> Channel<Void, Void> {
  return TimerSpec(deadline: .time(.now()),
                   interval: .seconds(interval),
                   leeway: nil,
                   cancellationToken: cancellationToken)
    .makeTimerChannel(executor: executor, {})
}

/// Makes channel of provides updates periodically
///
/// - Parameters:
///   - interval: in an *interval* (in seconds)
///   - executor: executor to
/// - Returns: channel
public func makeTimer<T>(
  executor: Executor = .primary,
  interval: Double,
  cancellationToken: CancellationToken? = nil,
  _ maker:  @escaping () throws -> T
  ) -> Channel<T, Void> {
  return TimerSpec(deadline: .time(.now()),
                   interval: .seconds(interval),
                   leeway: nil,
                   cancellationToken: cancellationToken)
    .makeTimerChannel(executor: executor, maker)
}
