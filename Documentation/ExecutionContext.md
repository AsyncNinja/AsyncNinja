# `ExecutionContext`
This document describes concept and use of `ExecutionContext`.

**For class reference visit [CocoaPods](http://cocoadocs.org/docsets/AsyncNinja/1.0.0-beta7/Protocols/ExecutionContext.html).**
**For more detailed explanation [visit](https://github.com/AsyncNinja/article-moving-to-nice-asynchronous-swift-code/blob/master/ARTICLE.md)**

##### Contents
* [Concept](#concept)
* [Relation to Concurrency Primitives](#relation-to-concurrency-primitives)
* [UI and Core](#ui-and-core)
* [List of predefined `ExecutionContext`s](#list-of-predefined-executioncontexts)

## Concept
`ExecutionContext` is a type that provides `Executor` and can retain objects while alive itself. `ExecutionContext` is a major part of [Memory Management](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/MemoryManagement.md).

Memory Management in asynchronous execution may be hard.

```swift
class WebService {
  let urlSession: URLSession
  let internalQueue: DispatchQueue // queue to modify internal state on
  /* ... */
  func signInUser(email: String, password: String,
    callback: @escaping (user: User?, error: Swift.Error?) -> Void) {
      /* ... */
  }
}
```

Okay, this code is already clunky. Let's use to `Future`s.

```swift
class WebService {
  let urlSession: URLSession
  let internalQueue: DispatchQueue // queue to modify internal state on
  /* ... */
  func signInUser(email: String, password: String) -> Future<User> {
    let request = self.makeSignInRequest(email: email, password: password)
    return self.urlSession.data(with: request)
      .map(executor: .queue(self.internalQueue)) { (data, response) -> User in
          let user = try self.makeUser(data: data, response: response)
          self.register(user: user) // changes internal state
          return user
        }
  }
}
```
This is a place where hidden memory issues may appear. Closure passed to `map` retains `self` that may lead to retain cycle. Adding bunch of `weak`s will help but it will increase complexity of code. Let's conform `WebService` to `ExecutionContext` and see what happens.

```swift
class WebService: ExecutionContext, ReleasePoolOwner {
  let urlSession: URLSession
  let internalQueue: DispatchQueue // queue to modify internal state on
  let releasePool = ReleasePool()
  /* ... */
  func signInUser(email: String, password: String) -> Future<User> {
    let request = self.makeSignInRequest(email: email, password: password)
    return self.urlSession.data(with: request)
      .map(context: self) { (self, dataAndResponse) -> User in
          let (data, response) = dataAndResponse
          let user = try self.makeUser(data: data, response: response)
          self.register(user: user) // changes internal state
                return user
       }
  }
}
```
`self` passed as argument to closure in `map`. `self` is not retained and execution depends on `WebService` lifetime, so you may not bother cancelling background operations on `WebService.deinit`.

## Relation to Concurrency Primitives
`Future`, `Channel` and `Channel` have contextual variants of all transformations. For example `Future` has both:

```swift
extension Future {
  func map<T>(executor: Executor, transform: @escaping (Value) throws -> T) -> Future<T>
  func map<T, U: ExecutionContext>(context: U, transform: @escaping (U, Value) throws -> T) -> Future<T>
}
```

It should help in making concurrency-aware active objects (actors and components of actors).

There are also some methods that are implemented to work with context only:

```swift
extension Future {
  func onComplete<U: ExecutionContext>(context: U, _ block: @escaping (U, Value) -> Void)
  func onSuccess<U: ExecutionContext>(context: U, _ block: @escaping (U, Success) -> Void)
  func onFailure<U: ExecutionContext>(context: U, _ block: @escaping (U, Swift.Error) -> Void)
}
```

As you might see these methods do not return any value. That means that they are made to change an internal state of `ExecutionContext`.

## UI and Core

Most of well-architecturally-designed apps on Apple platforms have strong segregation of UI and Core. UI-related calculations are executed on main queue all of the time. Core-related calculations are *mostly* in a background (using utility and background queues). Passing values between UI and Core involves a lot of dispatches to specific queues. It is also very easy to forget about those dispatches. Using `ExecutionContext` helps a lot.

##### Example

```swift
class NiceViewController: UIViewController {
  let webService: WebService
  var user: User?
  /* ... */
  @IBAction func signIn(_ sender: Any?) {
    self.webService.signInUser(email: self.emailField.text ?? "", password: self.passwordField.text ?? "")
      .onComplete(context: self) { (self, fallibleUser) in
          fallibleUser.onSuccess { self.user = $0 }
          fallibleUser.onFailure(self.present(error:))
        }
  }
  /* ... */
}
```

**What did just happen?**
On `signIn` web service will be requested for sign in. When resonse from web service arrived closure passed to `onComplete` will be called to on `Executor` provided by `ExecutionContext`. So we have

* clean code
* no retain cycles
* execution is automatically dispatched

What left is `NiceViewController` talking to a `WebService`.

> **...Wait**, but I did not conform NiceViewController to ExecutionContext.

You see, `UIResponder`/`NSResponder` and `UIViewController` in particular is considered as part of UI. We have two very obvious facts:

* UI always works on the main queue
* extending lifetime of UI object after it has been removed from hierarchy has no sense

Out of these facts, I conclude that `UIResponder`/`NSResponder` may automatically be conformed to `ExecutionContext`.

## List of predefined `ExecutionContext`s
* `UIResponder`/`NSResponder`
* `NSManagedObjectContext`
* `NSPersistentStoreCoordinator`
