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

import Dispatch

// MARK: - DispatchQueue

extension DispatchQueue: ExecutorImpl {
  var asyncNinja_representedDispatchQueue: DispatchQueue? { return self }
  var asyncNinja_canImmediatelyExecuteOnPrimaryExecutor: Bool { return false }

  func asyncNinja_execute(_ block: @escaping () -> Void) {
    async(execute: block)
  }

  func asyncNinja_execute(after timeout: Double, _ block: @escaping () -> Void) {
    let wallDeadline = DispatchWallTime.now().adding(seconds: timeout)
    asyncAfter(wallDeadline: wallDeadline, execute: block)
  }

  func asyncNinja_canImmediatelyExecute(from impl: ExecutorImpl) -> Bool {
    return impl === self
  }
}

// MARK: - DispatchGroup

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
        notify(queue: executor_.representedDispatchQueue!) { [weak promise] in
            promise?.succeed((), from: executor_)
        }
        return promise
    }

    /// Convenience method that leaves group on completion of provided Future or Channel
    func leaveOnComplete<T: Completing>(of completable: T) {
        completable.onComplete(executor: .immediate) { _ in self.leave() }
    }
}

// MARK: - DispatchTime

extension DispatchTime {
    func adding(seconds: Double) -> DispatchTime {
        #if arch(x86_64) || arch(arm64)
            return self + .nanoseconds(Int(seconds * 1_000_000_000.0))
        #else
            return self + .milliseconds(Int(seconds * 1_000.0))
        #endif
    }
}

// MARK: - DispatchWallTime

extension DispatchWallTime {
    func adding(seconds: Double) -> DispatchWallTime {
        #if arch(x86_64) || arch(arm64)
            return self + .nanoseconds(Int(seconds * 1_000_000_000.0))
        #else
            return self + .milliseconds(Int(seconds * 1_000.0))
        #endif
    }
}
