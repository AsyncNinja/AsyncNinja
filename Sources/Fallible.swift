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

#if swift(>=5.0)

public typealias Fallible<S> = Result<S, Swift.Error>

#else

/// Fallible is an implementation of validation monad.
/// May contain either success value or failure in form of `Error`.
public enum Fallible<Success>: _Fallible {
  public typealias Failure = Swift.Error

  /// success case of Fallible. Contains success value
  case success(Success)

  /// failure case of Fallible. Contains failure value (Error)
  case failure(Failure)

  /// Initializes Fallible with success value
  ///
  /// - Parameter success: value to initalize Fallible with
  public init(success: Success) {
    self = .success(success)
  }

  /// Initializes Fallible with failure valie
  ///
  /// - Parameter failure: error to initalize Fallible with
  public init(failure: Failure) {
    self = .failure(failure)
  }

  /// makes fallible with succees
  public static func just(_ success: Success) -> Fallible<Success> {
    return .success(success)
  }
}
#endif

// MARK: - Casting

public extension Fallible {

  /// Transforms the fallible to a fallible of unrelated type
  /// Correctness of such transformation is left on our behalf
  func staticCast<T>() -> Fallible<T> {
    switch self {
    case let .success(success):
      return .success(success as! T)
    case let .failure(failure):
      return .failure(failure)
    }
  }

  /// Transforms the fallible to a fallible of unrelated type
  /// Incorrect transformation will result into dynamicCastFailed failure
  func dynamicCast<T>() -> Fallible<T> {
    switch self {
    case let .success(success):
      if let castedSuccess = success as? T {
        return .success(castedSuccess)
      } else {
        return .failure(AsyncNinjaError.dynamicCastFailed)
      }
    case let .failure(failure):
      return .failure(failure)
    }
  }
}

// MARK: - Description
extension Fallible: CustomStringConvertible, CustomDebugStringConvertible {
  /// A textual representation of this instance.
  public var description: String {
    return description(withBody: "")
  }

  /// A textual representation of this instance, suitable for debugging.
  public var debugDescription: String {
    return description(withBody: "<\(Success.self)>")
  }

  /// **internal use only**
  private func description(withBody body: String) -> String {
    switch self {
    case .success(let value):
      return "success\(body)(\(value))"
    case .failure(let value):
      return "failure\(body)(\(value))"
    }
  }
}

// MARK: - state managers
public extension Fallible {

  #if swift(>=5.0)
  #else
  /// A legacy shortcut to maybeSuccess
  var success: Success? {
    return maybeSuccess
  }

  /// A legacy shortcut to maybeFailure
  var failure: Failure? {
    return maybeFailure
  }
  #endif

  /// Returns success if Fallible has a success value inside.
  /// Returns nil otherwise
  var maybeSuccess: Success? {
    switch self {
    case let .success(succes):
      return succes
    case .failure:
      return nil
    }
  }

  /// Returns failure if Fallible has a failure value inside.
  /// Returns nil otherwise
  var maybeFailure: Failure? {
    switch self {
    case .success:
      return nil
    case let .failure(failure):
      return failure
    }
  }

  #if swift(>=5.0)
  /// A legacy shortcut to get()
  func liftSuccess() throws -> Success {
    return try get()
  }
  #else
  /// This method is convenient when you want to transfer back
  /// to a regular Swift error handling
  ///
  /// - Returns: success value if Fallible has a success value inside
  /// - Throws: failure value if Fallible has a failure value inside
  func get() throws -> Success {
    switch self {
    case let .success(success): return success
    case let .failure(failure): throw failure
    }
  }
  #endif

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
  func onFailure(_ block: (_ failure: Failure) throws -> Void) rethrows {
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
  ///   - transform: block to apply.
  ///     A success value returned from block will be a success value of the transformed Fallible.
  ///     An error thrown from block will be a failure value of a transformed Fallible
  ///     **This block will not be executed if an original Fallible contains a failure.**
  ///     **That failure will become a failure value of a transfomed Fallible**
  ///   - success: success value of original Fallible
  /// - Returns: transformed Fallible
  func map<T>(_ transform: (_ success: Success) throws -> T) -> Fallible<T> {
    return self.flatMap { .success(try transform($0)) }
  }

  /// Applies transformation to Fallible and flattens nested Fallibles.
  ///
  /// - Parameters:
  ///   - transform: block to apply.
  ///     A fallible value returned from block will be a value (after flattening) of the transformed Fallible.
  ///     An error thrown from block will be a failure value of the transformed Fallible.
  ///     **This block will not be executed if an original Fallible contains a failure.**
  ///     **That failure will become a failure value of a transfomed Fallible**
  ///   - success: success value of original Fallible
  /// - Returns: transformed Fallible
  func flatMap<T>(_ transform: (_ success: Success) throws -> Fallible<T>) -> Fallible<T> {
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
  ///   - transform: block to apply.
  ///     A success value returned from block will be a success value of the transformed Fallible.
  ///     An error thrown from block will be a failure value of a transformed Fallible.
  ///     **This block will not be executed if an original Fallible contains a success value.**
  ///    **That success value will become a success value of a transfomed Fallible**
  ///   - failure: failure value of original Fallible
  /// - Returns: transformed Fallible
  func tryRecover(_ transform: (_ failure: Failure) throws -> Success) -> Fallible<Success> {
    switch self {
    case let .success(success):
      return .success(success)
    case let .failure(failure):
      do {
        return .success(try transform(failure))
      } catch {
        return .failure(error)
      }
    }
  }

  /// Applies non-throwable transformation to Fallible
  ///
  /// - Parameters:
  ///   - transform: block to apply.
  ///     A success value returned from block will be returned from method.
  ///     **This block will not be executed if an original Fallible contains a success value.**
  ///     **That success value will become a success value of a transfomed Fallible**
  ///   - failure: failure value of original Fallible
  /// - Returns: success value
  func recover(_ transform: (_ failure: Failure) -> Success) -> Success {
    switch self {
    case let .success(success):
      return success
    case let .failure(failure):
      return transform(failure)
    }
  }

  /// Applies non-throwable transformation to Fallible
  ///
  /// - Parameters:
  ///   - success: recover failure with
  /// - Returns: success value
  func recover(with success: Success) -> Success {
    switch self {
    case let .success(success):
      return success
    case .failure:
      return success
    }
  }
}

// MARK: - consturctors

/// Executes specified block and wraps a returned value or a thrown error with Fallible
///
/// - Parameter block: to execute.
///   A returned value will become success value of retured Fallible.
///   A thrown error will become failure value of returned Fallible.
/// - Returns: fallible constructed of a returned value or a thrown error with Fallible
public func fallible<T>(block: () throws -> T) -> Fallible<T> {
  do {
    return .success(try block())
  } catch {
    return .failure(error)
  }
}

/// Executes specified block and returns returned Fallible or wraps a thrown error with Fallible
///
/// - Parameter block: to execute.
///   A returned value will returned from method.
///   A thrown error will become failure value of returned Fallible.
/// - Returns: returned Fallible or a thrown error wrapped with Fallible
public func flatFallible<T>(block: () throws -> Fallible<T>) -> Fallible<T> {
  do {
    return try block()
  } catch {
    return .failure(error)
  }
}

// MARK: - flattening
extension Fallible where Success: _Fallible {
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
    case let .failure(failure):
      return .failure(failure)
    }
  }
}

/// **Internal use only**
/// The combination of protocol _Fallible and enum Fallible is a dirty hack of type system.
/// But there are no higher kinded types or generic protocols to implement it properly.
/// Major propose is an ability to implement flatten() method.
public protocol _Fallible: CustomStringConvertible {
  /// a type of a successful case value
  associatedtype Success
  associatedtype Failure

  /// returns success value if _Fallible contains one
  var maybeSuccess: Success? { get }

  /// returns failure value if _Fallible contains one
  var maybeFailure: Failure? { get }

  /// executes handler if the fallible containse success value
  func onSuccess(_ handler: (Success) throws -> Void) rethrows

  /// executes handler if the fallible containse failure value
  func onFailure(_ handler: (Failure) throws -> Void) rethrows

  /// (success or failure) * (try transform success to success) -> (success or failure)
  func map<T>(_ transform: (Success) throws -> T) -> Fallible<T>

  /// (success or failure) * (try transform success to (success or failure)) -> (success or failure)
  func flatMap<T>(_ transform: (Success) throws -> Fallible<T>) -> Fallible<T>

  /// (success or failure) * (try transform failure to success) -> (success or failure)
  func tryRecover(_ transform: (Failure) throws -> Success) -> Fallible<Success>

  /// (success or failure) * (transform failure to success) -> success
  func recover(_ transform: (Failure) -> Success) -> Success

  /// returns success or throws failure
  func get() throws -> Success
}

#if swift(>=5.0)
#else
// MARK: - equality
extension Fallible where Success: Equatable {
  /* TODO: update when conditional conformation becomes availble */

  /// Partial implementation of equality opeator for Fallibles
  /// You should check equalitu of unwrapped values rather then use this function
  public static func == (lhs: Fallible, rhs: Fallible) -> Bool {
    switch (lhs, rhs) {
    case let (.success(leftSuccess), .success(rightSuccess)):
      return leftSuccess == rightSuccess
    case let (.failure(leftFailure), .failure(rightFailure)):
      _ = leftFailure
      _ = rightFailure
      // TODO: figure out how to check equality of failures
      return false
    default:
      return false
    }
  }
}

// MARK: - hashing
extension Fallible where Success: Hashable {
  /* TODO: update when conditional conformation becomes availble */

  /// Partial implementation of hashValue for Fallibles
  /// You should get hashValue ofunwrapped values rather then use this method
  public var hashValue: Int {
    switch self {
    case let .success(value):
      return value.hashValue
    case let .failure(error):
      _ = error
      // TODO: figure out how to hash failures
      return 0
    }
  }
}
#endif

/// Combines successes of two failables or returns fallible with first error
public func zip<A, B>(
  _ a: Fallible<A>,
  _ b: Fallible<B>
  ) -> Fallible<(A, B)> {
  switch (a, b) {
  case let (.success(successA), .success(successB)):
    return .success((successA, successB))
  case let (.failure(failure), _),
       let (_, .failure(failure)):
    return .failure(failure)
  default:
    fatalError()
  }
}

/// Combines successes of tree failables or returns fallible with first error
public func zip<A, B, C>(
  _ a: Fallible<A>,
  _ b: Fallible<B>,
  _ c: Fallible<C>
  ) -> Fallible<(A, B, C)> {
  switch (a, b, c) {
  case let (.success(successA), .success(successB), .success(successC)):
    return .success((successA, successB, successC))
  case let (.failure(failure), _, _),
       let (_, .failure(failure), _),
       let (_, _, .failure(failure)):
    return .failure(failure)
  default:
    fatalError()
  }
}

#if swift(>=5.0)

extension Fallible: _Fallible { }

#endif
