//
//  appleOS.swift
//  FunctionalConcurrency
//
//  Created by Anton Mironov on 11.09.16.
//
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  import Foundation

  public extension ExecutionContext {
    static func operationQueue(_ queue: OperationQueue) -> Executor {
      return Executor(handler: queue.addOperation)
    }
  }

  public protocol ObjCInjectedExecutionContext : ExecutionContext, NSObjectProtocol { }

  public extension ObjCInjectedExecutionContext {
    func releaseOnDeinit(_ object: AnyObject) {
      Statics.withUniqueKey {
        objc_setAssociatedObject(self, $0, object, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
      }
    }
  }

  public protocol ObjCUIInjectedExecutionContext : ObjCInjectedExecutionContext { }
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

  extension NSManagedObjectContext : ObjCInjectedExecutionContext {
    public var executor: Executor { return Executor { [weak self] in self?.perform($0) } }
  }

  extension NSPersistentStoreCoordinator : ObjCInjectedExecutionContext {
    public var executor: Executor { return Executor { [weak self] in self?.perform($0) } }
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
