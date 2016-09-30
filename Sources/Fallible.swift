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

/// Fallible is an implementation of validation monad. May contain either success value or falilure in form of `Error`.
public enum Fallible<Success> : _Fallible {
  case success(Success)
  case failure(Swift.Error)

  public init(success: Success) {
    self = .success(success)
  }

  public init(failure: Swift.Error) {
    self = .failure(failure)
  }
}

public extension Fallible {
  var success: Success? {
    if case let .success(success) = self { return success }
    else { return nil }
  }

  var failure: Swift.Error? {
    if case let .failure(failure) = self { return failure }
    else { return nil }
  }

  func liftSuccess() throws -> Success {
    switch self {
    case let .success(success): return success
    case let .failure(error): throw error
    }
  }

  func onSuccess(_ handler: (Success) throws -> Void) rethrows {
    if case let .success(success) = self {
      try handler(success)
    }
  }

  func onFailure(_ handler: (Swift.Error) throws -> Void) rethrows {
    if case let .failure(failure) = self {
      try handler(failure)
    }
  }

  func map<T>(transform: (Success) throws -> T) -> Fallible<T> {
    return self.map { .success(try transform($0)) }
  }

  func map<T>(transform: (Success) throws -> Fallible<T>) -> Fallible<T> {
    switch self {
    case let .success(success):
      return fallible { try transform(success) }
    case let .failure(failure):
      return .failure(failure)
    }
  }

  func recover(transform: (Swift.Error) throws -> Success) -> Fallible<Success> {
    switch self {
    case let .success(success):
      return .success(success)
    case let .failure(error):
      do { return .success(try transform(error)) }
      catch { return .failure(error) }
    }
  }

  func recover(transform: (Swift.Error) -> Success) -> Success {
    switch self {
    case let .success(success):
      return success
    case let .failure(error):
      return transform(error)
    }
  }
}

//public extension Fallible where Success : _Fallible {
//  func flatten() -> Fallible<Success.Success> {
//    switch self {
//    case let .success(success):
//      switch success {
//      case let .success(success): return success
//      case let .failure(error): throw error
//      }
//    case let .failure(error): throw error
//    }
//  }
//}

public func fallible<T>(block: () throws -> T) -> Fallible<T> {
  do { return Fallible(success: try block()) }
  catch { return Fallible(failure: error) }
}

public func fallible<T>(block: () throws -> Fallible<T>) -> Fallible<T> {
  do { return try block() }
  catch { return Fallible(failure: error) }
}

//  The combination of protocol _Fallible and enum Fallible
//  is an dirty hack of type system. But there are no higher-kinded types
//  or generic protocols to implement it properly.

/// **internal use only**
public protocol _Fallible { // hacking type system once
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
  func map<T>(transform: (Success) throws -> Fallible<T>) -> Fallible<T>

  // (success or failure) * (try transform failure to success) -> (success or failure)
  func recover(transform: (Swift.Error) throws -> Success) -> Fallible<Success>

  // (success or failure) * (transform failure to success) -> success
  func recover(transform: (Swift.Error) -> Success) -> Success

  // returns success or throws failure
  func liftSuccess() throws -> Success
}
