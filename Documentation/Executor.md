# Executor
This document describes concept and use of `Executor`.

**For class reference visit [CocoaPods](http://cocoadocs.org/docsets/AsyncNinja/1.0.0-beta7/Structs/Executor.html).** 

##### Contents
* [Concept](#concept)
    * [Why?](#why)

## Concept
[`Executor`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/Executor.md) is an object that provides methods to execute an escaped block.

Propose of `Executor` is to encapsulate a way of an execution.
```swift
struct Executor {
    func execute(_ block: @escaping (Void) -> Void)
    func execute(after timeout: Double, _ block: @escaping (Void) -> Void)
}
```

##### Why?
There are multiple ways to execute block asynchronously: `DispatchQueue`, `OperationQueue`, `NSManagedObjectContext` and etc. You will pick one of them depending on your needs. `Executor` was introduced to accept any of them.

`Executor` is an often argument in methods found in `Future` and `Channel` to specify how block must be executed.
