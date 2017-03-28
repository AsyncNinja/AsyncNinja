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

import Foundation

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

// MARK: - Channel Event

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
