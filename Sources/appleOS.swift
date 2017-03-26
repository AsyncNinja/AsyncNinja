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
    
    /// makes an `Executor` from `OperationQueue`
    ///
    /// - Parameters:
    ///   - queue: an `OperationQueue` to make executor from
    ///   - isStrictAsync: `true` if the `Executor` must execute blocks strictly asynchronously.
    ///     `false` will relax requirements to increase performance
    /// - Returns: constructed `Executor`
    static func operationQueue(
      _ queue: OperationQueue,
      isStrictAsync: Bool = false
      ) -> Executor
    {
      return Executor(relaxAsyncWhenLaunchingFrom: isStrictAsync ? nil : ObjectIdentifier(queue),
                      handler: queue.addOperation)
    }
  }

  /// A protocol that automatically adds implementation of methods
  /// of `Retainer` for Objective-C runtime compatible objects
  public protocol ObjCInjectedRetainer: Retainer, NSObjectProtocol { }

  /// **Internal use only** An object that calls specified block on deinit
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
        "asyncNinjaKey_\($0)".withCString {
          objc_setAssociatedObject(self, $0, object,
                                   .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
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

  // **internal use only**
  private struct Statics {
    static var increment: OSAtomic_int64_aligned64_t = 0
    static func withUniqueKey(_ block: (Int64) -> Void) {
      let unique = OSAtomicIncrement64Barrier(&increment)
      block(unique)
    }
  }

  extension EventSource where Update: NSObject {

    /// Returns channel of distinct update values of original channel.
    /// Works only for collections of equatable values
    /// [objectA, objectA, objectB, objectC, objectC, objectA] => [objectA, objectB, objectC, objectA]
    ///
    /// - Parameters:
    ///   - cancellationToken: `CancellationToken` to use.
    ///     Keep default value of the argument unless you need
    ///     an extended cancellation options of returned channel
    ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
    ///     Keep default value of the argument unless you need
    ///     an extended buffering options of returned channel
    /// - Returns: channel with distinct update values
    public func distinctNSObjects(cancellationToken: CancellationToken? = nil,
                                  bufferSize: DerivedChannelBufferSize = .default
      ) -> Channel<Update, Success> {

      // Test: EventSource_TransformTests.testDistinctNSObjects
      return distinct(cancellationToken: cancellationToken, bufferSize: bufferSize) {
        return $0.isEqual($1)
      }
    }
  }

  extension EventSource where Update: Collection, Update.Iterator.Element: NSObject {

    /// Returns channel of distinct update values of original channel.
    /// Works only for collections of NSObjects values
    /// [[objectA], [objectA], [objectA, objectB], [objectA, objectB, objectC], [objectA, objectB, objectC], [objectA]] => [[objectA], [objectA, objectB], [objectA, objectB, objectC], [objectA]]
    ///
    /// - Parameters:
    ///   - cancellationToken: `CancellationToken` to use.
    ///     Keep default value of the argument unless you need
    ///     an extended cancellation options of returned channel
    ///   - bufferSize: `DerivedChannelBufferSize` of derived channel.
    ///     Keep default value of the argument unless you need
    ///     an extended buffering options of returned channel
    /// - Returns: channel with distinct update values
    public func distinctCollectionOfNSObjects(cancellationToken: CancellationToken? = nil,
                                              bufferSize: DerivedChannelBufferSize = .default
      ) -> Channel<Update, Success> {

      // Test: EventSource_TransformTests.testDistinctArrayOfNSObjects
      return distinct(cancellationToken: cancellationToken, bufferSize: bufferSize) {
        return $0.count == $1.count
          && !zip($0, $1).contains { !$0.isEqual($1) }
      }
    }
  }

  /// Binds two event streams bidirectionally.
  ///
  /// - Parameters:
  ///   - majorStream: a stream to bind to. This stream has a priority during initial synchronization
  ///   - minorStream: a stream to bind to.
  ///   - valueTransformer: `ValueTransformer` to use to transform from T.Update to U.Update and reverse
  public func doubleBind<T: EventSource&EventsDestination, U: EventSource&EventsDestination>(
    _ majorStream: T,
    _ minorStream: U,
    valueTransformer: ValueTransformer)
  {
    doubleBind(majorStream,
               transform: { valueTransformer.transformedValue($0) as! U.Update },
               minorStream,
               reverseTransform: { valueTransformer.reverseTransformedValue($0) as! T.Update })
  }
  
#endif

#if os(macOS) || os(iOS)
  
  import WebKit
  
  // MARK: - reactive properties for WKWebView
  public extension ReactiveProperties where Object: WKWebView {

    /// An `Sink` that refers to write-only `WKWebView.load(_:)`
    var loadRequest: Sink<URLRequest, Void> { return sink { $0.load($1) } }
    
    /// An `Sink` that refers to write-only `WKWebView.loadFileURL(_:, allowingReadAccessTo:)`
    @available(OSX 10.11, iOS 9, *)
    var loadFileURL: Sink<(url: URL, readAccessURL: URL), Void> {
      return sink { $0.loadFileURL($1.url, allowingReadAccessTo: $1.readAccessURL) }
    }
    
    /// An `Sink` that refers to write-only `WKWebView.loadHTMLString(_:, baseURL:)`
    var loadHTMLString: Sink<(string: String, baseURL: URL?), Void> { return sink { $0.loadHTMLString($1.string, baseURL: $1.baseURL) } }
    
    /// An `Sink` that refers to write-only `load(_:, mimeType:, characterEncodingName:, baseURL:)`
    @available(OSX 10.11, iOS 9, *)
    var loadData: Sink<(data: Data, mimeType: String, characterEncodingName: String, baseURL: URL), Void> {
      return sink { $0.load($1.data, mimeType: $1.mimeType, characterEncodingName: $1.characterEncodingName, baseURL: $1.baseURL) }
    }
  }
  
#endif
