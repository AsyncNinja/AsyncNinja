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

// swiftlint:disable line_length

/// Protocol for concurrency-aware active objects.
/// Conforming to this protocol helps to avoid boilerplate code related to dispatching and memory management.
/// See ["Moving to nice asynchronous Swift code"](https://github.com/AsyncNinja/article-moving-to-nice-asynchronous-swift-code/blob/master/ARTICLE.md) for complete explanation.
///
/// Best way to conform for model-related classes looks like:
///
/// ```swift
/// public class MyService: ExecutionContext, ReleasePoolOwner {
///   private let _internalQueue = DispatchQueue(label: "my-service-queue", target: .global())
///   public var executor: Executor { return .queue(_internalQueue) }
///   public let releasePool = ReleasePool()
///
///   /* class implementation */
/// }
/// ```
///
/// Best way to conform for classes related to main queue looks like:
///
/// ```swift
/// public class MyMainQueueService: ExecutionContext, ReleasePoolOwner {
///   public var executor: Executor { return .main }
///   public let releasePool = ReleasePool()
///
///   /* class implementation */
/// }
/// ```
///
/// Best way to conform for classes related to UI manipulations looks like:
///
/// ```swift
/// public class MyPresenter: NSObject, ObjCUIInjectedExecutionContext {
///   /* class implementation */
/// }
/// ```
/// Classes that conform to NSResponder/UIResponder are automatically conformed to exection context.
public protocol ExecutionContext: Retainer {

  /// Executor to perform internal state-changing operations on.
  /// It is highly recommended to use serial executor
  var executor: Executor { get }
}

// swiftlint:enable line_length

public extension ExecutionContext {
  /// Schedules execution of the block
  ///
  /// - Parameters:
  ///   - cancellationToken: `CancellationToken` that can cancel execution
  ///   - block: to schedule after timeout
  ///   - strongSelf: is `ExecutionContext` restored from weak reference of self
  func async(cancellationToken: CancellationToken? = nil,
             block: @escaping (_ strongContext: Self) -> Void) {
    self.executor.execute(from: nil) { [weak self] (_) in
      guard let strongSelf = self else { return }
      block(strongSelf)
    }
  }

  /// Schedules execution of the block after specified timeout
  ///
  /// - Parameters:
  ///   - timeout: (in seconds) to execute the block after
  ///   - cancellationToken: `CancellationToken` that can cancel execution
  ///   - block: to schedule after timeout
  ///   - strongSelf: is `ExecutionContext` restored from weak reference of self
  func after(_ timeout: Double, cancellationToken: CancellationToken? = nil,
             block: @escaping (_ strongContext: Self) -> Void) {
    self.executor.execute(after: timeout) { [weak self] (_) in
      if cancellationToken?.isCancelled ?? false { return }
      guard let strongSelf = self else { return }
      block(strongSelf)
    }
  }

  /// Adds dependent `Cancellable`. `Cancellable` will be weakly referenced
  /// and cancelled on deinit
  func addDependent(cancellable: Cancellable) {
    self.notifyDeinit { [weak cancellable] in
      cancellable?.cancel()
    }
  }

  /// Adds dependent `Completable`. `Completable` will be weakly
  /// referenced and cancelled because of deallocated context on deinit
  func addDependent<T: Completable>(completable: T) {
    self.notifyDeinit { [weak completable] in
      completable?.cancelBecauseOfDeallocatedContext()
    }
  }

  /// Makes a dynamic property bound to the execution context
  ///
  /// - Parameters:
  ///   - initialValue: initial value to set
  ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
  ///     Keep default value of the argument unless you need
  ///     an extended buffering options of returned channel
  /// - Returns: `DynamicProperty` bound to the context
  func makeDynamicProperty<T>(
    _ initialValue: T,
    bufferSize: Int = AsyncNinjaConstants.defaultChannelBufferSize
    ) -> DynamicProperty<T> {
    return DynamicProperty(
      initialValue: initialValue,
      updateExecutor: executor,
      bufferSize: bufferSize)
  }
}

/// Protocol for any instance that has `ReleasePool`.
/// Made to proxy calls of `func releaseOnDeinit(_ object: AnyObject)`
/// and `func notifyDeinit(_ block: @escaping () -> Void)` to `ReleasePool`
public protocol ReleasePoolOwner: Retainer {

  /// `ReleasePool` to proxy calls to. Perfect implementation looks like:
  /// ```swift
  /// public class MyService: ExecutionContext, ReleasePoolOwner {
  ///  let releasePool = ReleasePool()
  ///  /* other implementation */
  /// }
  /// ```
  var releasePool: ReleasePool { get }
}

public extension ExecutionContext where Self: ReleasePoolOwner {
  func releaseOnDeinit(_ object: AnyObject) {
    self.releasePool.insert(object)
  }

  func notifyDeinit(_ block: @escaping () -> Void) {
    self.releasePool.notifyDrain(block)
  }
}

/// An object that can extend lifetime of another objects up to deinit or notify deinit
public protocol Retainer: class {

  /// Extends lifetime of specified object
  func releaseOnDeinit(_ object: AnyObject)

  /// calls specified block on deinit
  func notifyDeinit(_ block: @escaping () -> Void)
}
