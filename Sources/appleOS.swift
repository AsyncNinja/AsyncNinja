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

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  import Foundation

  public extension Executor {
    static func operationQueue(_ queue: OperationQueue) -> Executor {
      return Executor(handler: queue.addOperation)
    }
  }

  public protocol ObjCInjectedRetainer : Retainer, NSObjectProtocol { }

  private class DeinitNotifier {
    let block: () -> Void
    init(block: @escaping () -> Void) {
      self.block = block
    }

    deinit { self.block() }
  }

  public extension ObjCInjectedRetainer {
    func releaseOnDeinit(_ object: AnyObject) {
      Statics.withUniqueKey {
        objc_setAssociatedObject(self, $0, object, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
      }
    }

    func notifyDeinit(_ block: @escaping () -> Void) {
      self.releaseOnDeinit(DeinitNotifier(block: block))
    }
  }

  public protocol ObjCUIInjectedExecutionContext : ExecutionContext, ObjCInjectedRetainer { }
  public extension ObjCUIInjectedExecutionContext {
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

  extension NSManagedObjectContext : ExecutionContext, ObjCInjectedRetainer {
    public var executor: Executor { return Executor(isSerial: true) { [weak self] in self?.perform($0) } }
  }

  extension NSPersistentStoreCoordinator : ExecutionContext, ObjCInjectedRetainer {
    public var executor: Executor { return Executor(isSerial: true) { [weak self] in self?.perform($0) } }
  }

  public extension URLSession {
    private func dataFuture(context: ExecutionContext?, cancellationToken: CancellationToken?, makeTask: (@escaping (Data?, URLResponse?, Swift.Error?) -> Void) -> URLSessionDataTask) -> Future<(Data?, URLResponse)> {
      let promise = Promise<(Data?, URLResponse)>()
      let task = makeTask { [weak promise] (data, response, error) in
        guard let promise = promise else { return }
        guard let error = error else {
          promise.succeed(with: (data, response!))
          return
        }
        if let urlError = error as? URLError, urlError.errorCode == URLError.cancelled.rawValue {
          promise.fail(with: AsyncNinjaError.cancelled)
        } else {
          promise.fail(with: error)
        }
      }
      promise.notifyDrain { [weak task] in task?.cancel() }
      cancellationToken?.notifyCancellation {
        [weak task, weak promise] in
        task?.cancel()
        promise?.cancel()
      }
      context?.notifyDeinit {
        [weak task, weak promise] in
        task?.cancel()
        promise?.cancelBecauseOfDeallicatedContext()
      }

      task.resume()
      return promise
    }

    func data(at url: URL, context: ExecutionContext? = nil, cancellationToken: CancellationToken? = nil) -> Future<(Data?, URLResponse)> {
      return self.dataFuture(context: context, cancellationToken: cancellationToken) {
        self.dataTask(with: url, completionHandler: $0)
      }
    }

    func data(with request: URLRequest, context: ExecutionContext? = nil, cancellationToken: CancellationToken? = nil) -> Future<(Data?, URLResponse)> {
      return self.dataFuture(context: context, cancellationToken: cancellationToken) {
        self.dataTask(with: request, completionHandler: $0)
      }
    }

    func upload(with request: URLRequest, fromFile fileURL: URL, context: ExecutionContext? = nil, cancellationToken: CancellationToken? = nil) -> Future<(Data?, URLResponse)> {
      return self.dataFuture(context: context, cancellationToken: cancellationToken) {
        self.uploadTask(with: request, fromFile: fileURL, completionHandler: $0)
      }
    }

    func upload(with request: URLRequest, from bodyData: Data?, context: ExecutionContext? = nil, cancellationToken: CancellationToken? = nil) -> Future<(Data?, URLResponse)> {
      return self.dataFuture(context: context, cancellationToken: cancellationToken) {
        self.uploadTask(with: request, from: bodyData, completionHandler: $0)
      }
    }
  }
#endif

#if os(macOS)
  import AppKit

  extension NSResponder : ObjCUIInjectedExecutionContext {}
#endif

#if os(iOS) || os(tvOS)
  import UIKit

  extension UIResponder : ObjCUIInjectedExecutionContext {}
#endif

#if os(watchOS)
  import WatchKit

  extension WKInterfaceController : ObjCUIInjectedExecutionContext {}
  extension WKInterfaceObject : ObjCUIInjectedExecutionContext {}
#endif
