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

/// Fallible is an implementation of validation monad. May contain either success value or failure in form of `Error`.
public enum Fallible<Success> : _Fallible {
  case success(Success)
  case failure(Swift.Error)

  /// Initializes Fallible with success value
  ///
  /// - Parameter success: value to initalize Fallible with
  public init(success: Success) {
    self = .success(success)
  }

  /// Initializes Fallible with failure valie
  ///
  /// - Parameter failure: error to initalize Fallible with
  public init(failure: Swift.Error) {
    self = .failure(failure)
  }
}

/// MARK: - state managers
public extension Fallible {

  /// Returns success if Fallible has a success value inside. Returns nil otherwise
  var success: Success? {
    if case let .success(success) = self { return success }
    else { return nil }
  }

  /// Returns failure if Fallible has a failure value inside. Returns nil otherwise
  var failure: Swift.Error? {
    if case let .failure(failure) = self { return failure }
    else { return nil }
  }

  /// This method is convenient when you want to transfer back to a regular Swift error handling
  ///
  /// - Returns: success value if Fallible has a success value inside
  /// - Throws: failure value if Fallible has a failure value inside
  func liftSuccess() throws -> Success {
    switch self {
    case let .success(success): return success
    case let .failure(error): throw error
    }
  }

  /// Executes block if Fallible has success value inside
  ///
  /// - Parameters:
  ///     - handler: handler to execute
  ///     - success: success value of Fallible
  /// - Throws: rethrows an error thrown by the block
  func onSuccess(_ block: (_ success: Success) throws -> Void) rethrows {
    if case let .success(success) = self {
      try block(success)
    }
  }

  /// Executes block if Fallible has failure value inside
  ///
  /// - Parameters:
  ///     - handler: handler to execute
  ///     - failure: failure value of Fallible
  /// - Throws: rethrows an error thrown by the block
  func onFailure(_ block: (_ failure: Swift.Error) throws -> Void) rethrows {
    if case let .failure(failure) = self {
      try block(failure)
    }
  }
}

// MARK: - transformers
public extension Fallible {
  /// Applies transformation to Fallible
  ///
  /// - Parameters:
  ///   - transform: block to apply. A success value returned from block will be a success value of the transformed Fallible. An error thrown from block will be a failure value of a transformed Fallible. **This block will not be executed if an original Fallible contains a failure. That failure will become a failure value of a transfomed Fallible**
  ///   - success: success value of original Fallible
  /// - Returns: transformed Fallible
  func map<T>(transform: (_ success: Success) throws -> T) -> Fallible<T> {
    return self.flatMap { .success(try transform($0)) }
  }

  /// Applies transformation to Fallible and flattens nested Fallibles.
  ///
  /// - Parameters:
  ///   - transform: block to apply. A fallible value returned from block will be a value (after flattening) of the transformed Fallible. An error thrown from block will be a failure value of the transformed Fallible. **This block will not be executed if an original Fallible contains a failure. That failure will become a failure value of a transfomed Fallible**
  ///   - success: success value of original Fallible
  /// - Returns: transformed Fallible
  func flatMap<T>(transform: (_ success: Success) throws -> Fallible<T>) -> Fallible<T> {
    switch self {
    case let .success(success):
      return flatFallible { try transform(success) }
    case let .failure(failure):
      return .failure(failure)
    }
  }

  /// Applies transformation to Fallible
  ///
  /// - Parameters:
  ///   - transform: block to apply. A success value returned from block will be a success value of the transformed Fallible. An error thrown from block will be a failure value of a transformed Fallible. **This block will not be executed if an original Fallible contains a success value. That success value will become a success value of a transfomed Fallible**
  ///   - failure: failure value of original Fallible
  /// - Returns: transformed Fallible
  func tryRecover(transform: (_ failure: Swift.Error) throws -> Success) -> Fallible<Success> {
    switch self {
    case let .success(success):
      return .success(success)
    case let .failure(error):
      do { return .success(try transform(error)) }
      catch { return .failure(error) }
    }
  }

  /// Applies non-trowable transformation to Fallible
  ///
  /// - Parameters:
  ///   - transform: block to apply. A success value returned from block will be returned from method. **This block will not be executed if an original Fallible contains a success value. That success value will become a success value of a transfomed Fallible**
  ///   - failure: failure value of original Fallible
  /// - Returns: success value
  func recover(transform: (_ failure: Swift.Error) -> Success) -> Success {
    switch self {
    case let .success(success):
      return success
    case let .failure(error):
      return transform(error)
    }
  }
}

// MARK: - consturctors

/// Executes specified block and wraps a returned value or a thrown error with Fallible
///
/// - Parameter block: to execute. A returned value will become success value of retured Fallible. A thrown error will become failure value of returned Fallible
/// - Returns: fallible constructed of a returned value or a thrown error with Fallible
public func fallible<T>(block: () throws -> T) -> Fallible<T> {
  do { return Fallible(success: try block()) }
  catch { return Fallible(failure: error) }
}

/// **Deprecated. Use flatFallible(block:) instead.**
///
/// Executes specified block and returns returned Fallible or wraps a thrown error with Fallible.
///
/// - Parameter block: to execute. A returned value will returned from method. A thrown error will become failure value of returned Fallible
/// - Returns: returned Fallible or a thrown error wrapped with Fallible
@available(*, deprecated: 0.3.4, renamed: "flatFallible")
public func fallible<T>(block: () throws -> Fallible<T>) -> Fallible<T> {
  do { return try block() }
  catch { return Fallible(failure: error) }
}

/// Executes specified block and returns returned Fallible or wraps a thrown error with Fallible
///
/// - Parameter block: to execute. A returned value will returned from method. A thrown error will become failure value of returned Fallible
/// - Returns: returned Fallible or a thrown error wrapped with Fallible
public func flatFallible<T>(block: () throws -> Fallible<T>) -> Fallible<T> {
  do { return try block() }
  catch { return Fallible(failure: error) }
}

// MARK: - flattening
extension Fallible where Success : _Fallible {
  /// Flattens two nested Fallibles:
  /// ```
  /// < <Success> > => <Success>
  /// < <Failure> > => <Failure>
  ///   <Failure>   => <Failure>
  /// ```
  ///
  /// - Returns: flattened Fallible
public func flatten() -> Fallible<Success.Success> {
    switch self {
    case let .success(success):
      return success as! Fallible<Success.Success>
    case let .failure(error):
      return .failure(error)
    }
  }
}

/// **Internal use only**
/// The combination of protocol _Fallible and enum Fallible is a dirty hack of type system. But there are no higher kinded types or generic protocols to implement it properly. Major propose is an ability to implement flatten() method.
public protocol _Fallible {
  associatedtype Success

  var success: Success? { get }
  var failure: Swift.Error? { get }

  init(success: Success)
  init(failure: Swift.Error)

  func onSuccess(_ handler: (Success) throws -> Void) rethrows
  func onFailure(_ handler: (Swift.Error) throws -> Void) rethrows

  // (success or failure) * (try transform success to success) -> (success or failure)
  func map<T>(transform: (Success) throws -> T) -> Fallible<T>

  // (success or failure) * (try transform success to (success or failure)) -> (success or failure)
  func flatMap<T>(transform: (Success) throws -> Fallible<T>) -> Fallible<T>

  // (success or failure) * (try transform failure to success) -> (success or failure)
  func tryRecover(transform: (Swift.Error) throws -> Success) -> Fallible<Success>

  // (success or failure) * (transform failure to success) -> success
  func recover(transform: (Swift.Error) -> Success) -> Success

  // returns success or throws failure
  func liftSuccess() throws -> Success
}

// MARK: - equality
extension Fallible where Success : Equatable {
  /* TODO: update when conditional conformation becomes availble */

  /// Partial implementation of equality opeator for Fallibles
  /// You should check equalitu of unwrapped values rather then use this function
  public static func ==(lhs: Fallible, rhs: Fallible) -> Bool {
    switch (lhs, rhs) {
    case let (.success(leftSuccess), .success(rightSuccess)):
      return leftSuccess == rightSuccess
    case let (.failure(leftFailure), .failure(rightFailure)):
      let _ = leftFailure
      let _ = rightFailure
      // TODO: figure out how to check equality of failures
      return false
    default:
      return false
    }
  }
}

// MARK: - hashing
extension Fallible where Success : Hashable {
  /* TODO: update when conditional conformation becomes availble */

  /// Partial implementation of hashValue for Fallibles
  /// You should get hashValue ofunwrapped values rather then use this method
  public var hashValue: Int {
    switch self {
    case let .success(value):
      return value.hashValue
    case let .failure(error):
      let _ = error
      // TODO: figure out how to hash failures
      return 0
    }
  }
}
