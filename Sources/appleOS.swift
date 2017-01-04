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

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)

  import Foundation

  public extension Executor {

    /// Convenience function that makes executor from `OperationQueue`
    static func operationQueue(_ queue: OperationQueue) -> Executor {
      return Executor(handler: queue.addOperation)
    }
  }

  /// A protocol that automatically adds implementation of methods
  /// of `Retainer` for Objective-C runtime compatible objects
  public protocol ObjCInjectedRetainer: Retainer, NSObjectProtocol {
  }

  private class DeinitNotifier {
    let _block: () -> Void

    init(block: @escaping () -> Void) {
      _block = block
    }

    deinit { _block() }
  }

  public extension ObjCInjectedRetainer {
    func releaseOnDeinit(_ object: AnyObject) {
      Statics.withUniqueKey {
        objc_setAssociatedObject(self, $0, object,
                                 .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
      }
    }

    func notifyDeinit(_ block: @escaping () -> Void) {
      releaseOnDeinit(DeinitNotifier(block: block))
    }
  }

  /// Is a protocol that automatically adds implementation of methods
  /// of `ExecutionContext` for Objective-C runtime compatible objects
  /// involved in UI manipulations
  public protocol ObjCUIInjectedExecutionContext: ExecutionContext, ObjCInjectedRetainer {
  }

  public extension ObjCUIInjectedExecutionContext {
    /// executor for ui objects. The main queue
    var executor: Executor { return .main }
  }

  private struct Statics {
    static var increment: OSAtomic_int64_aligned64_t = 0
    static func withUniqueKey(_ block: (UnsafeRawPointer) -> Void) {
      let unique = OSAtomicIncrement64Barrier(&increment)
      let capacity = 2
      let key = UnsafeMutablePointer<Int64>.allocate(capacity: capacity)
      defer { key.deallocate(capacity: capacity) }
      key.initialize(from: [unique, 0])
      block(key)
    }
  }

  import CoreData

  /// NSManagedObjectContext improved with AsyncNinja
  extension NSManagedObjectContext: ExecutionContext, ObjCInjectedRetainer {

    /// returns an executor that executes block on private queue of NSManagedObjectContext
    public var executor: Executor {
      return Executor(isSerial: true) {
        [weak self] in
        self?.perform($0) }
    }
  }

  /// NSPersistentStoreCoordinator improved with AsyncNinja
  extension NSPersistentStoreCoordinator: ExecutionContext, ObjCInjectedRetainer {

    /// returns an executor that executes block on private queue of NSPersistentStoreCoordinator
    public var executor: Executor {
      return Executor(isSerial: true) {
        [weak self] in
        self?.perform($0)
      }
    }
  }

  /// Conformance URLSessionTask to Cancellable
  extension URLSessionTask: Cancellable {

  }

  /// URLSession improved with AsyncNinja
  public extension URLSession {

    private typealias URLSessionCallback = (Data?, URLResponse?, Swift.Error?) -> Void
    private typealias MakeURLTask = (@escaping URLSessionCallback) -> URLSessionDataTask
    private func dataFuture(context: ExecutionContext?,
                            cancellationToken: CancellationToken?,
                            makeTask: MakeURLTask) -> Future<(Data?, URLResponse)> {
      let promise = Promise<(Data?, URLResponse)>()
      let task = makeTask { [weak promise] (data, response, error) in
        guard let promise = promise else { return }
        guard let error = error else {
          promise.succeed(with: (data, response!))
          return
        }

        if let cancellationRepresentable = error as? CancellationRepresentableError,
          cancellationRepresentable.representsCancellation {
          promise.fail(with: AsyncNinjaError.cancelled)
        } else {
          promise.fail(with: error)
        }
      }

      promise.notifyDrain { [weak task] in task?.cancel() }
      cancellationToken?.add(cancellable: task)
      cancellationToken?.add(cancellable: promise)
      context?.addDependent(cancellable: task)
      context?.addDependent(finite: promise)

      task.resume()
      return promise
    }

    /// Makes data task and returns Future of response
    func data(at url: URL,
              context: ExecutionContext? = nil,
              cancellationToken: CancellationToken? = nil
      ) -> Future<(Data?, URLResponse)> {
      return dataFuture(context: context, cancellationToken: cancellationToken) {
        dataTask(with: url, completionHandler: $0)
      }
    }

    /// Makes data task and returns Future of response
    func data(with request: URLRequest,
              context: ExecutionContext? = nil,
              cancellationToken: CancellationToken? = nil
      ) -> Future<(Data?, URLResponse)> {
      return dataFuture(context: context, cancellationToken: cancellationToken) {
        dataTask(with: request, completionHandler: $0)
      }
    }

    /// Makes upload task and returns Future of response
    func upload(with request: URLRequest,
                fromFile fileURL: URL,
                context: ExecutionContext? = nil,
                cancellationToken: CancellationToken? = nil
      ) -> Future<(Data?, URLResponse)> {
      return dataFuture(context: context, cancellationToken: cancellationToken) {
        uploadTask(with: request, fromFile: fileURL, completionHandler: $0)
      }
    }

    /// Makes upload task and returns Future of response
    func upload(with request: URLRequest,
                from bodyData: Data?,
                context: ExecutionContext? = nil,
                cancellationToken: CancellationToken? = nil
      ) -> Future<(Data?, URLResponse)> {
      return dataFuture(context: context, cancellationToken: cancellationToken) {
        uploadTask(with: request, from: bodyData, completionHandler: $0)
      }
    }
  }

#endif

#if os(macOS)

  import AppKit

  /// Conforms NSResponer to ObjCUIInjectedExecutionContext that allows
  /// using each NSResponder as ExecutionContext
  extension NSResponder: ObjCUIInjectedExecutionContext {
  }

#endif

#if os(iOS) || os(tvOS)

  import UIKit

  /// Conforms UIResponder to ObjCUIInjectedExecutionContext that allows
  /// using each UIResponder as ExecutionContext
  extension UIResponder: ObjCUIInjectedExecutionContext {
  }

#endif

#if os(watchOS)

  import WatchKit

  /// Conforms WKInterfaceController to ObjCUIInjectedExecutionContext
  /// that allows using each WKInterfaceController as ExecutionContext
  extension WKInterfaceController: ObjCUIInjectedExecutionContext {
  }

  /// Conforms WKInterfaceObject to ObjCUIInjectedExecutionContext
  /// that allows using each WKInterfaceObject as ExecutionContext
  extension WKInterfaceObject: ObjCUIInjectedExecutionContext {
  }
  
#endif
