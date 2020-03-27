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

  /// Conformance URLSessionTask to Cancellable
  extension URLSessionTask: Cancellable { }

  /// URLSession improved with AsyncNinja
  public extension URLSession {

    /// Makes data task and returns Future of response
    func data(
      at url: URL,
      cancellationToken: CancellationToken? = nil
      ) -> Future<(Data?, URLResponse)> {
      return dataFuture(cancellationToken: cancellationToken) {
        dataTask(with: url, completionHandler: $0)
      }
    }

    /// Makes data task and returns Future of response
    func data(
      with request: URLRequest,
      cancellationToken: CancellationToken? = nil
      ) -> Future<(Data?, URLResponse)> {
      return dataFuture(cancellationToken: cancellationToken) {
        dataTask(with: request, completionHandler: $0)
      }
    }

    /// Makes upload task and returns Future of response
    func upload(
      with request: URLRequest,
      fromFile fileURL: URL,
      cancellationToken: CancellationToken? = nil
      ) -> Future<(Data?, URLResponse)> {
      return dataFuture(cancellationToken: cancellationToken) {
        uploadTask(with: request, fromFile: fileURL, completionHandler: $0)
      }
    }

    /// Makes upload task and returns Future of response
    func upload(
      with request: URLRequest,
      from bodyData: Data?,
      cancellationToken: CancellationToken? = nil
      ) -> Future<(Data?, URLResponse)> {
      return dataFuture(cancellationToken: cancellationToken) {
        uploadTask(with: request, from: bodyData, completionHandler: $0)
      }
    }

    /// Makes download task and returns Future of response
    func download(
      at sourceURL: URL,
      to destinationURL: URL,
      cancellationToken: CancellationToken? = nil
      ) -> Future<URL> {
      return downloadFuture(to: destinationURL, cancellationToken: cancellationToken) {
        downloadTask(with: sourceURL, completionHandler: $0)
      }
    }

    /// Makes download task and returns Future of response
    func download(
      with request: URLRequest,
      to destinationURL: URL,
      cancellationToken: CancellationToken? = nil
      ) -> Future<URL> {
      return downloadFuture(to: destinationURL, cancellationToken: cancellationToken) {
        downloadTask(with: request, completionHandler: $0)
      }
    }
  }

  fileprivate extension URLSession {
    /// a shortcut to url session callback
    typealias URLSessionCallback = (Data?, URLResponse?, Swift.Error?) -> Void
    /// a shortcut to url session task construction
    typealias MakeURLTask = (@escaping URLSessionCallback) -> URLSessionDataTask
    func dataFuture(
      cancellationToken: CancellationToken?,
      makeTask: MakeURLTask) -> Future<(Data?, URLResponse)> {
      let promise = Promise<(Data?, URLResponse)>()
      let task = makeTask { [weak promise] (data, response, error) in
        guard let promise = promise else { return }
        guard let error = error else {
          promise.succeed((data, response!), from: nil)
          return
        }

        if let cancellationRepresentable = error as? CancellationRepresentableError,
          cancellationRepresentable.representsCancellation {
          promise.cancel(from: nil)
        } else {
          promise.fail(error, from: nil)
        }
      }

      promise._asyncNinja_notifyFinalization { [weak task] in task?.cancel() }
      cancellationToken?.add(cancellable: task)
      cancellationToken?.add(cancellable: promise)

      task.resume()
      return promise
    }

    /// a shortcut to url session callback
    typealias DownloadTaskCallback = (URL?, URLResponse?, Swift.Error?) -> Void
    /// a shortcut to url session task construction
    typealias MakeDownloadTask = (@escaping DownloadTaskCallback) -> URLSessionDownloadTask
    func downloadFuture(
      to destinationURL: URL,
      cancellationToken: CancellationToken?,
      makeTask: MakeDownloadTask) -> Future<URL> {
      let promise = Promise<URL>()
      let task = makeTask { [weak promise] (temporaryURL, _, error) in
        guard let promise = promise else { return }
        if let error = error {
          if let cancellationRepresentable = error as? CancellationRepresentableError,
            cancellationRepresentable.representsCancellation {
            promise.cancel(from: nil)
          } else {
            promise.fail(error, from: nil)
          }
        } else if let temporaryURL = temporaryURL {
          do {
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
            promise.succeed(destinationURL)
          } catch { promise.fail(error) }
          return
        } else {
          promise.fail(NSError(domain: URLError.errorDomain, code: URLError.dataNotAllowed.rawValue))
        }
      }

      promise._asyncNinja_notifyFinalization { [weak task] in task?.cancel() }
      cancellationToken?.add(cancellable: task)
      cancellationToken?.add(cancellable: promise)

      task.resume()
      return promise
    }
  }

#endif
