//
//  appleOS.swift
//  FunctionalConcurrency
//
//  Created by Anton Mironov on 11.09.16.
//
//

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) ||
  import Foundation

  public extension ExecutionContext {
    public static func queue(_ queue: OperationQueue) -> Executor {
      return Executor(handler: queue.addOperation)
    }
  }
#endif
