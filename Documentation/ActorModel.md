# Actor Model

This document explains why and how to build [Actor Model](https://en.wikipedia.org/wiki/Actor_model) using AsyncNinja framework.

## Why?
> Actors may modify private state, but can only affect each other through messages (avoiding the need for any locks).

Actor Model is a simple abstraction for concurrent computation. It provides a reliable way to implement extensible concurrent solutions without trapping into[race conditions](https://en.wikipedia.org/wiki/Race_condition#Software) and [deadlocks](https://en.wikipedia.org/wiki/Deadlock).

## How? (Suggested Implementation)

*	import AsyncNinja
*	introduce a class with it's own internal queue and conform it to `ExecutionContext`
*	implement public methods that look like:
```swift
public makeSomething(arg1: Arg1, arg2: Arg2) -> Future<Something>
```

#### Example
```swift
import AsyncNinja

public class MyActor {
	public func perform(request: SimpleRequest) -> Future<SimpleResponse> {
		return future(context: self) { try $0._perform(request: request) }
	}
	
	private func _perform(request: SimpleRequest) throws -> SimpleResponse {
		// do work
		return SimpleResponse()
	}
}

extension MyActor: ExecutionContext 
      let internalQueue = DispatchQueue(label: "com.company.app.my-actor", attributes: [], target: .global())
      var executor: Executor { return .queue(self.internalQueue) }
      let releasePool = ReleasePool()
}
```

## What about UI?
UI-related objects (windows, views, view controllers and etc) are mostly bound to main queue/thread. They may be considered as components of some imaginery (or real) actor that changes it's state on main queue. Conform your UI-related to `ExecutionContext` protocol and enjoy concurrency with neat [memory management](MemoryManagement.md).

#### Example

```swift
import AsyncNinja

class MyViewController: UIViewController {
	let myActor = MyActor()

	@IBAction func doWork(_ sender: AnyObject?) {
		self.myActor.perform(request: SimpleRequest())
			.onComplete(context: self) { (value, self_) in
				value.onSuccess(self_.present(response:))
				value.onFailure(self_.present(error:))
			}
	}
	
	func present(response: SimpleResponse) {
		// present response
	}
	
	func present(error: Swift.Error) {
		// present error
	}
}

extension MyViewController: ExecutionContext {
	let executor = Executor.main
	let releasePool = ReleasePool()
}
```
