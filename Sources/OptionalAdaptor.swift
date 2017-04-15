//
//  Copyright (c) 2017 Anton Mironov
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

/// This protocol helps to hack type system in order to write where clauses for Optional's wrapped type
public protocol AsyncNinjaOptionalAdaptor: ExpressibleByNilLiteral {
  /// The same as Optional.Wrapped
  associatedtype AsyncNinjaWrapped

  /// Init with optional
  init(asyncNinjaOptionalValue: AsyncNinjaWrapped?)

  /// Returns optional
  var asyncNinjaOptionalValue: AsyncNinjaWrapped? { get }
}

extension Optional: AsyncNinjaOptionalAdaptor {
  /// The same as Optional.Wrapped
  public typealias AsyncNinjaWrapped = Wrapped

  /// Init with optional
  public init(asyncNinjaOptionalValue: AsyncNinjaWrapped?) {
    self = asyncNinjaOptionalValue
  }

  /// Returns optional
  public var asyncNinjaOptionalValue: AsyncNinjaWrapped? { return self }
}

/// Adds convenience members to the channel that who's Update is optional
public extension Channel where U: AsyncNinjaOptionalAdaptor {
  typealias UnwrappedUpdate = Update.AsyncNinjaWrapped

  /// makes channel of unsafely unwrapped optional Updates
  var unsafelyUnwrapped: Channel<UnwrappedUpdate, Success> {
    return map(executor: .immediate) { $0.asyncNinjaOptionalValue.unsafelyUnwrapped }
  }

  /// makes channel of unwrapped optional Updates or noneReplacement values
  func unwrapped(_ noneReplacement: UnwrappedUpdate) -> Channel<Update.AsyncNinjaWrapped, Success> {
    return map(executor: .immediate) { (update: Update) -> UnwrappedUpdate in
      return update.asyncNinjaOptionalValue ?? noneReplacement
    }
  }
}

/// Adds convenience members to the future that who's Success is optional
public extension Future where S: AsyncNinjaOptionalAdaptor {
  typealias UnwrappedSuccess = Success.AsyncNinjaWrapped

  /// makes channel of unsafely unwrapped optional Updates
  var unsafelyUnwrapped: Future<UnwrappedSuccess> {
    return map(executor: .immediate) { $0.asyncNinjaOptionalValue.unsafelyUnwrapped }
  }

  /// makes channel of unwrapped optional Updates or noneReplacement values
  func unwrapped(_ noneReplacement: UnwrappedSuccess) -> Future<UnwrappedSuccess> {
    return map(executor: .immediate) { (success: Success) -> UnwrappedSuccess in
      return success.asyncNinjaOptionalValue ?? noneReplacement
    }
  }
}
