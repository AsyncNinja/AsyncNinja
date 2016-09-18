# Executor

[`Executor`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Executor.md) is an object that provides methods to execute an escaped block.

##### Contents
* [Concept](#concept)
    * [Why?](#why)
* [Reference](#reference)
    * [Acquiring Executor](#acquiring-executor)

## Concept
Propose of `Executor` is to encapsulate a way of an execution.
```
struct Executor {
    func execute(_ block: @escaping (Void) -> Void)
    func execute(after timeout: Double, _ block: @escaping (Void) -> Void)
}
```

##### Why?
There are multiple ways to execute block asynchronously: `DispatchQueue`, `OperationQueue`, `NSManagedObjectContext` and etc. You will pick one of them depending on your needs. `Executor` was introduced to accept any of them.

`Executor` is an often argument in methods found in `Future`, `Channel` and `FiniteChannel` to specify how closure must be executed.

## Reference
#### Acquiring Executor
* using constant
    * `primary` executor is primary because it will be used as default value when executor argument is ommited for **most** methods
    * `main` queue executor 
    * global `userInteractive` queue executor
    * global `userInitiated` queue executor
    * global `default` queue executor
    * global `utility` queue executor. **do most of heavy calculations here**
    * global `background` queue executor
    * `immediate` executes block on the same stack value arrives. Not suitable for long running calculations. Default value of argument for **few** methods (such as `filter(...)`)
* creating new `Executor`
    * `Executor.init(handler: @escaping (@escaping (Void) -> Void) -> Void)`
    * `static func Executor.queue(_ queue: DispatchQueue) -> Executor`
    * `static func Executor.queue(_ qos: DispatchQoS.QoSClass) -> Executor`
