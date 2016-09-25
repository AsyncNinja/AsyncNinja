#    AsyncNinja is a concurrency library for Swift

Toolset for typesafe, threadsafe, memory leaks safe concurrency in Swift 3.

![License:MIT](https://img.shields.io/github/license/mashape/apistatus.svg)
![Platform:macOS|iOS|tvOS|watchOS|Linux](https://img.shields.io/badge/platform-macOS%7CiOS%7CtvOS%7CwatchOS%7CLinux-orange.svg)
![Swift](https://img.shields.io/badge/Swift-3.0-orange.svg)

[Found issue? Have a feature request? Have question?](https://github.com/AsyncNinja/AsyncNinja/issues)

[Current Progress](https://github.com/AsyncNinja/AsyncNinja/projects/1)

##    Basics
This framework is an implementation of following principles:

*    provide abstraction that makes
    *    doing right things easier
    *    doing wrong things harder
*    use abstraction is based on monads
    *    [`Future`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Future.md) is a proxy of value that will be available at some point in the future. See example for advances of using futures.
    *    [`InfiniteChannel`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/InfiniteChannel.md) (renamed from Stream because of some odd naming conflict with standard library) is the same as future but the value will appear multiple times.
    *    [`Channel`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Channel.md) is a combination of `Future` and `InfiniteChannel`.
    *    [`Executor`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Executor.md) is object made to execute escaped block `(Void) -> Void`. Its propose is to encapsulate a way of an execution.
    *    [`ExecutionContext`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/ExecutionContext.md) is a protocol concurrency-aware objects must conform to. It basically make them actors or components of actor.
    *    [`Fallible`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Fallible.md) is validation monad. Is an object that represents either success value of failure value (Error).

###Primitives
|               |`Finite`|`Periodic`|
|---------------|:------:|:--------:|
|`Future`       | ✓      | ✕        |
|`InfiniteChannel`      | ✕      | ✓        |
|`Channel`| ✓      | ✓        |


##    Documentation
*    [`Future`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Future.md)
*    [`InfiniteChannel`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Channel.md)
*    [`Channel`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Channel.md)
*    [`Executor`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Executor.md)
*    [`ExecutionContext`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/ExecutionContext.md)
*    [`Fallible`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Fallible.md)
*    [Actor Model](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/ActorModel.md)
*    [Memory Management](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/MemoryManagement.md)
