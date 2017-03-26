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

/// Constatns used my AsyncNinja
/// Values of these constants were carefully considered
struct AsyncNinjaConstants {
  #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  /// Defines whether usage of lock-free structures is allowed
  static let isLockFreeUseAllowed = true
  #endif

  /// Defines size of buffer for channels.
  /// Buffer size is an amount of the latest values for channel to remember
  ///
  /// Example:
  /// ```swift
  /// let producer = Producer<Int, Void>(bufferSize: ...)
  /// producer.update([0, 1, 2])
  /// producer.onUpdate { print($0) }
  /// producer.update([3, 4, 5])
  /// ```
  /// Output will depend on buffer size:
  /// - 0: `3 4 5`
  /// - 1: `2 3 4 5`
  /// - 2: `1 2 3 4 5`
  ///
  /// This kind of behavior is present in each way of interaction
  /// with `Channel`: transformation, sync enumeration and etc.
  static let defaultChannelBufferSize = 1
}

/// Errors produced by AsyncNinja
public enum AsyncNinjaError: Swift.Error, Equatable {
  /// An error of cancelled primitive. `Promises` and `Producers`
  /// can be cancecelled with method `cancel()`.
  /// CancellationToken may be used in multiple other cases
  case cancelled

  /// An error of deallocated context
  /// Basically means that execution was bound to context,
  /// by context was deallocated before execution started
  case contextDeallocated

  /// An error of failed dynamic cast
  case dynamicCastFailed
}

/// Convenience protocol for detection cancellation
public protocol CancellationRepresentableError: Swift.Error {

  /// returns true if the error is actually a cancellation
  var representsCancellation: Bool { get }
}

/// Conformance of AsyncNinjaError to CancellationRepresentableError
extension AsyncNinjaError: CancellationRepresentableError {

  /// returns true if the error is actually a cancellation
  public var representsCancellation: Bool { return .cancelled == self }
}

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

  import Foundation

  /// Conformance to CancellationRepresentableError
  extension URLError: CancellationRepresentableError {

    /// tells if this error is actually a cancellation
    public var representsCancellation: Bool {
      return self.errorCode == URLError.cancelled.rawValue
    }
  }
  
#endif

extension Dictionary {
  mutating func value(forKey key: Key,
                      orMake makeValue: (Key) throws -> Value
    ) rethrows -> Value {
    if let existingValue = self[key] {
      return existingValue
    } else {
      let newValue = try makeValue(key)
      self[key] = newValue
      return newValue
    }
  }
}

func nop() {
  // no operation
}

func assertAbstract(file: StaticString = #file, line: UInt = #line) -> Never {
  fatalError("This methods is abstract. May not reach here", file: file, line: line)
}

// MARK: - Either

/// Simple implementation of either monad
public enum Either<Left, Right> {

  /// left case
  case left(Left)

  /// right case
  case right(Right)

  /// returns left value if there is one
  public var left: Left? {
    if case let .left(value) = self { return value }
    else { return nil }
  }

  /// returns right value if there is one
  public var right: Right? {
    if case let .right(value) = self { return value }
    else { return nil }
  }

  /// Transforms left value of `Either`. Does nothing if the value contains right
  ///
  /// - Parameter transform: closure that transforms Left to T
  /// - Returns: transformed `Either`
  /// - Throws: rethrows error thrown from transform
  public func mapLeft<T>(_ transform: (Left) throws -> T) rethrows -> Either<T, Right> {
    switch self {
    case let .left(left):
      return .left(try(transform(left)))
    case let .right(right):
      return .right(right)
    }
  }

  /// Transforms right value of `Either`. Does nothing if the value contains left
  ///
  /// - Parameter transform: closure that transforms Right to T
  /// - Returns: transformed `Either`
  /// - Throws: rethrows error thrown from transform
  public func mapRight<T>(_ transform: (Right) throws -> T) rethrows -> Either<Left, T> {
    switch self {
    case let .left(left):
      return .left(left)
    case let .right(right):
      return .right(try(transform(right)))
    }
  }

  /// Transforms the either to a either of unrelated type
  /// Correctness of such transformation is left on our behalf
  public func staticCast<L, R>() -> Either<L, R> {
    switch self {
    case let .left(left):
      return .left(left as! L)
    case let .right(right):
      return .right(right as! R)
    }
  }
}

// MARK: - Description
extension Either: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of this instance.
  public var description: String {
    return description(withBody: "")
  }

  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    return description(withBody: "<\(Left.self), \(Right.self)>")
  }

  /// **internal use only**
  private func description(withBody body: String) -> String {
    switch self {
    case .left(let value):
      return "left\(body)(\(value))"
    case .right(let value):
      return "right\(body)(\(value))"
    }
  }
}

// MARK: - Equatable
extension Either where Left: Equatable, Right: Equatable {

  /// implementation of an "equals" operatior
  public static func ==(lhs: Either, rhs: Either) -> Bool {
    switch (lhs, rhs) {
    case let (.left(valueA), .left(valueB)):
      return valueA == valueB
    case let (.right(valueA), .right(valueB)):
      return valueA == valueB
    default:
      return false
    }
  }
}

extension DispatchTime {
  func adding(seconds: Double) -> DispatchTime {
    #if arch(x86_64) || arch(arm64)
      return self + .nanoseconds(Int(seconds * 1_000_000_000.0))
    #else
      return self + .milliseconds(Int(seconds * 1_000.0))
    #endif
  }
}

extension DispatchWallTime {
  func adding(seconds: Double) -> DispatchWallTime {
    #if arch(x86_64) || arch(arm64)
      return self + .nanoseconds(Int(seconds * 1_000_000_000.0))
    #else
      return self + .milliseconds(Int(seconds * 1_000.0))
    #endif
  }
}

/// Value reveived by channel
public enum ChannelEvent<Update, Success> {
  /// A kind of value that can be received multiple times be for the completion one
  case update(Update)

  /// A kind of value that can be received once and completes the channel
  case completion(Fallible<Success>)
}

public extension ChannelEvent {

  /// Convenence initializer of ChannelEvent.completion
  ///
  /// - Parameter success: success value to complete with
  /// - Returns: successful completion channel event
  static func success(_ success: Success) -> ChannelEvent {
    return .completion(.success(success))
  }

  /// Convenence initializer of ChannelEvent.completion
  ///
  /// - Parameter failure: error to complete with
  /// - Returns: failure completion channel event
  static func failure(_ error: Swift.Error) -> ChannelEvent {
    return .completion(.failure(error))
  }

  /// Transforms the event to a event of unrelated type
  /// Correctness of such transformation is left on our behalf
  func staticCast<U, S>() -> ChannelEvent<U, S> {
    switch self {
    case let .update(update):
      return .update(update as! U)
    case let .completion(completion):
      return .completion(completion.staticCast())
    }
  }
}

/// DispatchGroup improved with AsyncNinja
public extension DispatchGroup {
  /// Makes future from of `DispatchGroups`'s notify after balancing all enters and leaves
  var completionFuture: Future<Void> {
    // Test: FutureTests.testGroupCompletionFuture
    return completionFuture(executor: .primary)
  }

  /// Makes future from of `DispatchGroups`'s notify after balancing all enters and leaves
  /// *Property `DispatchGroup.completionFuture` most cover most of your cases*
  ///
  /// - Parameter executor: to notify on
  /// - Returns: `Future` that completes with balancing enters and leaves of the `DispatchGroup`
  func completionFuture(executor: Executor) -> Future<Void> {
    let promise = Promise<Void>()
    let executor_ = executor.dispatchQueueBasedExecutor
    self.notify(queue: executor_.representedDispatchQueue!) { [weak promise] in
      promise?.succeed((), from: executor_)
    }
    return promise
  }

  /// Convenience method that leaves group on completion of provided Future or Channel
  func leaveOnComplete<T: Completing>(of completable: T) {
    completable.onComplete(executor: .immediate) { _ in self.leave() }
  }
}

/// Specifies strategy of selecting buffer size of channel derived
/// from another channel, e.g through transformations
public enum DerivedChannelBufferSize {

  /// Specifies strategy to use as default value for arguments of methods
  case `default`

  /// Buffer size is defined by the buffer size of original channel
  case inherited

  /// Buffer size is defined by specified value
  case specific(Int)

  /// **internal use only**
  func bufferSize<T: EventSource>(_ updating: T) -> Int {
    switch self {
    case .default: return AsyncNinjaConstants.defaultChannelBufferSize
    case .inherited: return updating.maxBufferSize
    case let .specific(value): return value
    }
  }

  /// **internal use only**
  func bufferSize<T: EventSource, U: EventSource>(
    _ leftUpdating: T,
    _ rightUpdating: U
    ) -> Int {
    switch self {
    case .default: return AsyncNinjaConstants.defaultChannelBufferSize
    case .inherited: return max(leftUpdating.maxBufferSize, rightUpdating.maxBufferSize)
    case let .specific(value): return value
    }
  }
}

/// **Internal use only**
class Box<T> {
  let value: T

  init(_ value: T) {
    self.value = value
  }
}

/// **Internal use only**
class MutableBox<T> {
  var value: T

  init(_ value: T) {
    self.value = value
  }
}

/// **Internal use only**
class WeakBox<T: AnyObject> {
  private(set) weak var value: T?

  init(_ value: T) {
    self.value = value
  }
}

/// **Internal use only**
class HalfRetainer<T> {
  let box: MutableBox<T?>

  init(box: MutableBox<T?>) {
    self.box = box
  }

  deinit {
    box.value = nil
  }
}
