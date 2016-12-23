# AsyncNinja is a concurrency library for Swift

Toolset for typesafe, threadsafe, memory leaks safe concurrency in Swift 3.

![License:MIT](https://img.shields.io/github/license/mashape/apistatus.svg)
![Platform:macOS|iOS|tvOS|watchOS|Linux](https://img.shields.io/badge/platform-macOS%7CiOS%7CtvOS%7CwatchOS%7CLinux-orange.svg)
![Swift](https://img.shields.io/badge/Swift-3.0-orange.svg)
![Build Status](https://travis-ci.org/AsyncNinja/AsyncNinja.svg?branch=master)

* [**Integration**](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/Integration.md)
* [Found issue? Have a feature request? Have question?](https://github.com/AsyncNinja/AsyncNinja/issues)

## Basics
This framework is an implementation of following principles:

* provide abstraction that makes
	* doing right things easier
	* doing wrong things harder
* use abstraction is based on monads
    * [`Future`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/Future.md) is a proxy of value that will be available at some point in the future. See example for advances of using futures.
    * [`Channel`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/Channel.md) is like a `Future` that may provide `Periodic` values before final one.
    * [`Executor`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/Executor.md) is object made to execute escaped block `(Void) -> Void`. Its propose is to encapsulate a way of an execution.
    * [`ExecutionContext`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/ExecutionContext.md) is a protocol concurrency-aware objects must conform to. It basically make them actors or components of actor.
    * [`Fallible`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/Fallible.md) is validation monad. Is an object that represents either success value of failure value (Error).
	* `Cache` is a primitive that lets you coalesce requests and cache responses

## Documentation
* [`Future`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/Future.md)
* [`Channel`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/Channel.md)
* [`Executor`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/Executor.md)
* [`ExecutionContext`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/ExecutionContext.md)
* [`Fallible`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/Fallible.md)
* [Actor Model](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/ActorModel.md)
* [Memory Management](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/MemoryManagement.md)
* [Integration](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/Integration.md)

## Related Articles
* [Moving to nice asynchronous Swift code](https://github.com/AsyncNinja/article-moving-to-nice-asynchronous-swift-code/blob/master/ARTICLE.md)
