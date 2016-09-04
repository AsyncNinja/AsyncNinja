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

import Foundation

//  The combination of protocol _Fallible and enum Fallible
//  is an dirty hack of type system. But there are no higher-kinded types
//  or generic protocols to implement it properly.

public protocol _Fallible { // hacking type system once
  associatedtype Success

  var successValue: Success? { get }
  var failureValue: Error? { get }

  init(success: Success)
  init(failure: Error)

  func onSuccess(_ handler: (Success) throws -> Void) rethrows
  func onFailure(_ handler: (Error) throws -> Void) rethrows

  // (success or failure) * (try transfrom success to success) -> (success or failure)
  func liftSuccess<T>(transform: (Success) throws -> T) -> Fallible<T>

  // (success or failure) * (try transfrom success to (success or failure)) -> (success or failure)
  func liftSuccess<T>(transform: (Success) throws -> Fallible<T>) -> Fallible<T>

  // (success or failure) * (try transfrom failure to success) -> (success or failure)
  func liftFailure(transform: (Error) throws -> Success) -> Fallible<Success>

  // (success or failure) * (transfrom failure to success) -> success
  func liftFailure(transform: (Error) -> Success) -> Success
}

public enum Fallible<T> : _Fallible {
  public typealias Success = T

  case success(Success)
  case failure(Error)

  public var successValue: Success? {
    if case let .success(successValue) = self { return successValue }
    else { return nil }
  }

  public var failureValue: Error? {
    if case let .failure(failureValue) = self { return failureValue }
    else { return nil }
  }

  public init(success: Success) {
    self = .success(success)
  }

  public init(failure: Error) {
    self = .failure(failure)
  }

  public func onSuccess(_ handler: (Success) throws -> Void) rethrows {
    if case let .success(successValue) = self {
      try handler(successValue)
    }
  }

  public func onFailure(_ handler: (Error) throws -> Void) rethrows {
    if case let .failure(failureValue) = self {
      try handler(failureValue)
    }
  }

  public func liftSuccess<T>(transform: (Success) throws -> T) -> Fallible<T> {
    return self.liftSuccess { .success(try transform($0)) }
  }

  public func liftSuccess<T>(transform: (Success) throws -> Fallible<T>) -> Fallible<T> {
    switch self {
    case let .success(successValue):
      return fallible { try transform(successValue) }
    case let .failure(failureValue):
      return .failure(failureValue)
    }
  }

  public func liftFailure(transform: (Error) throws -> Success) -> Fallible<Success> {
    switch self {
    case let .success(successValue):
      return .success(successValue)
    case let .failure(error):
      do { return .success(try transform(error)) }
      catch { return .failure(error) }
    }
  }

  public func liftFailure(transform: (Error) -> Success) -> Success {
    switch self {
    case let .success(successValue):
      return successValue
    case let .failure(error):
      return transform(error)
    }
  }
}

public func fallible<T>(block: () throws -> T) -> Fallible<T> {
  do { return Fallible(success: try block()) }
  catch { return Fallible(failure: error) }
}

public func fallible<T>(block: () throws -> Fallible<T>) -> Fallible<T> {
  do { return try block() }
  catch { return Fallible(failure: error) }
}
