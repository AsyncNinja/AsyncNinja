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
public struct AsyncNinjaConstants {
  #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  /// Defines whether usage of lock-free structures is allowed
  public static let isLockFreeUseAllowed = true
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
  public static let defaultChannelBufferSize = 1
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

  /// This error can be thrown (or complete primitive) if network
  /// reachability setup failed
  case networkReachabilityDetectionFailed
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

extension Optional {
  var isSome: Bool {
    if case .some = self {
      return true
    } else {
      return false
    }
  }

  var isNone: Bool {
    if case .none = self {
      return true
    } else {
      return false
    }
  }
}

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
