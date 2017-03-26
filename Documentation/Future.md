# `Future`
This document describes concept and use of `Future`.

**For class reference visit [CocoaPods](http://cocoadocs.org/docsets/AsyncNinja/1.0.0-beta7/Classes/Future.html).** 

##### Contents
* [Concept](#concept)
    * [Example: Solution based on callbacks](#solution-based-on-callbacks)
    * [Example: Solution based on futures](#solution-based-on-futures)
* [Promises](#promises)

## Concept
[As Wikipedia says](https://en.wikipedia.org/wiki/Futures_and_promises) `Future` is an object that acts as a proxy for a result that is initially unknown, usually because the computation of its value is yet incomplete. 

The straightforward solution will be using callback closure.

```swift
func perform(request: Request, callback: @escaping (Response) -> Void)
```

But this solution has multiple disadvantages:

* so called ["callback hell"](http://callbackhell.com) or ["pyramid of doom"](https://en.wikipedia.org/wiki/Pyramid_of_doom_(programming))
* combining multiple asynchronous operations is a complete disaster
*  it is hard to think of response as a result of operation because it placed inside function arguments
* be very attentive to memory management within callback closure

Function declaration that incorporates `Future` will look like this:

```swift
func perform(request: Request) -> Future<Response>
```

Solutions based on `Future`

* are shorter
* you are getting something as returned value
* are designed to be highly combinable
* AsyncNinja's [memory management](https://github.com/AsyncNinja/AsyncNinja/blob/master/Documentation/MemoryManagement.md) helps to avoid majority of memory issues

#### Example

##### Solution based on callbacks
```swift
protocol MaterialsProvider {
  func provideRubber(_ callback: (Rubber) -> Void)
  func provideMetal(_ callback: (Metal) -> Void)
}

protocol CarFactory {
  var materialsProvider: MaterialsProvider { get }
  func makeWheel(_ callback: @escaping (Car.Wheel) -> Void)
  func makeBody(_ callback: @escaping (Car.Body) -> Void)
  func makeCar(_ callback: @escaping (Car) -> Void)
}

extension CarFactory {
  func makeWheel(_ callback: @escaping (Car.Wheel) -> Void) {
    self.materialsProvider.provideRubber { rubber in
      // use rubber to make wheel
      callback(wheel)
    }
  }

  func makeBody(_ callback: @escaping (Car.Body) -> Void) {
    self.materialsProvider.provideMetal { metal in
      // use metal to make body
      callback(body)
    }
  }

  func makeCar(_ callback: @escaping (Car) -> Void) {
    let group = DispatchGroup()

    var body: Car.Body? = nil
    group.enter()
    makeBody {
      body = $0
      group.leave()
    }

    let sema = DispatchSemaphore(value: 1)
    let numberOfWheels = 4
    var wheels = Array<Car.Wheel?>(repeating: nil, count: numberOfWheels)
    for index in 0..<numberOfWheels {
      group.enter()
      makeWheel {
      sema.wait()
      wheels[index] = $0
      sema.signal()
      group.leave()
      }
    }

    DispatchQueue.global(qos: .utility).async(group: group) {
      // use body and wheels to make car
      callback(car)
    }
  }
}
```
##### Solution based on futures
```swift
protocol MaterialsProvider {
  func provideRubber() -> Future<Rubber>
  func provideMetal() -> Future<Metal>
}

protocol CarFactory {
  var materialsProvider: MaterialsProvider { get }
  func makeWheel() -> Future<Car.Wheel>
  func makeBody() -> Future<Car.Body>
  func makeCar() -> Future<Car>
}

extension CarFactory {
  func makeWheel() -> Future<Car.Wheel> {
    return self.materialsProvider
      .provideRubber()
      .map { rubber -> Car.Wheel in
      // use rubber to make wheel
      return wheel
    }
  }

  func makeBody() -> Future<Car.Body> {
    return self.materialsProvider
      .provideMetal()
      .map { metal -> Car.Body in
      // use metal to make body
      return body
    }
  }

  func makeCar() -> Future<Car> {
    let futureBody = self.makeBody()
    let futureWheels = (0..<4).map { _ in self.makeWheel() }
    return zip(futureBody, futureWheels)
      .map { (body, wheels) in
      // use body and wheels to make car
      return car
    }
  }
}
```

## Promises
`Promise` is a subclass of `Future` that provides control over completion.

There are multiple ways to use this class. Never the less `Promise` introduces mutable state in places where a mutable state could have been easily avoided. So it is suggested to avoid often usage.

Most of the usual case is a transition from callbacks-based flow to futures-based flow:

```swift
extension MyService {

  func fetchPerson(withID personID: Person.Identifier) -> Future<Person> {
    let promise = Promise<Person>()

    self.fetchPerson(withID: personID) { (person, error) in
      switch (person, error) {
      case let (.some(person), .none):
        promise.succeed(person)
      case let (.none, .some(error)):
        promise.fail(error)
      default:
        fatalError("callback must return either person or error")
      }
    }

    return promise
  }
  
}
```

**For the sake of symmetry.** Here is an example of a transition from future-based to callback-based:

```swift
extension MyService {

  func fetchPerson(withID personID: Person.Identifier,
                   callback: @escaping (Person?, Error?) -> Void) {
    self.fetchPerson(withID: personID)
      .onComplete { callback($0.success, $0.failure) }
  }
  
}
```

#### Tiny Improvement
Sample code above might look ugly. We can take a tiny step further and replace tuple `(Person?, Error?)` with `Fallible<Person>` to improve the transition from callbacks-based to futures-based:

```swift
extension MyService {

  func fetchPerson(withID personID: Person.Identifier) -> Future<Person> {
    let promise = Promise<Person>()
    self.fetchPerson(withID: personID, callback: promise.complete)
    return promise
  }

}
```

The transition from future-based to callback-based:

```swift
extension MyService {

  func fetchPerson(withID personID: Person.Identifier,
                   callback: @escaping (Fallible<Person>) -> Void) {
    self.fetchPerson(withID: personID)
      .onComplete(block: callback)
  }

```
