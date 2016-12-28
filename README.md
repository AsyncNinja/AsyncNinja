# AsyncNinja is a concurrency library for Swift

Toolset for typesafe, threadsafe, memory leaks safe concurrency in Swift 3.

![License:MIT](https://img.shields.io/github/license/mashape/apistatus.svg)
![Platform:macOS|iOS|tvOS|watchOS|Linux](https://img.shields.io/badge/platform-macOS%7CiOS%7CtvOS%7CwatchOS%7CLinux-orange.svg)
![Swift](https://img.shields.io/badge/Swift-3.0-orange.svg)
![Swift Package Manager Supported](https://img.shields.io/badge/Swift%20Package%20Manager-Supported-orange.svg)
![CocoaPods](https://img.shields.io/cocoapods/v/AsyncNinja.svg)
![Build Status](https://travis-ci.org/AsyncNinja/AsyncNinja.svg?branch=master)

* [**Integration**](Documentation/Integration.md): [SPM](https://github.com/apple/swift-package-manager), [CocoaPods](http://cocoadocs.org/docsets/AsyncNinja/)
* [Found issue? Have a feature request? Have question?](https://github.com/AsyncNinja/AsyncNinja/issues)

Contents

* [Why AsyncNinja?](#why-asyncninja)
* [Implemented Primitives](#implemented-primitives)
* [Using Futures](#using-futures)
* [Using Channels](#using-channels)
* [Documentation](#documentation)
* [Related Articles](#related-articles)

![Ninja Cat](https://github.com/AsyncNinja/AsyncNinja/blob/master/NinjaCat.png)

## Why AsyncNinja?

Let's assume that we have:

* `Person` is an example of a struct that contains information about the person.
* `MyService` is an example of a class that serves as an entry point to the model. Works in background.
* `MyViewController` is an example of a class that manages UI-related instances. Works on the main queue.

#### Code on callbacks

```swift
extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier) {

      /* do not forget the [weak self] */
      [weak self] (person, error) in

      /* do not forget to dispatch to the main queue */
      DispatchQueue.main.async {

        /* do not forget the [weak self] */
        [weak self] in
        guard let strongSelf = self else { return }

        if let error = error {
          strongSelf.present(error: error)
        } else {
          strongSelf.present(person: person)
        }
      }
    }
  }
}
```

* "do not forget" comment **x3**

#### Code with other libraries that provide futures

```swift
extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier)

      /* do not forget to dispatch to the main queue */
      .onComplete(executor: .main) {

        /* do not forget the [weak self] */
        [weak self] (personOrError) in
        guard let strongSelf = self else { return }

        switch personOrError {
        case .success(let person):
          strongSelf.present(person: person)
        case .failure(let error):
          strongSelf.present(error: error)
        }
    }
  }
}
```

* "do not forget" comment **x2**

#### Code with AsyncNinja

```swift
extension MyViewController {
  func present(personWithID identifier: String) {
    self.myService.person(identifier: identifier)
      .onComplete(context: self) {
        (self, personOrError) in

        switch personOrError {
        case .success(let person):
          self.present(person: person)
        case .failure(let error):
          self.present(error: error)
        }
    }
  }
}
```

* "do not forget" comment **NONE**
* [Want to see extended explanation?](https://medium.com/@AntonMironov/moving-to-nice-asynchronous-swift-code-7b0cb2eadde1)

## Implemented Primitives
This framework is an implementation of following principles:

* provide abstraction that makes
	* doing right things easier
	* doing wrong things harder
* use abstraction is based on monads
    * [`Future`](Documentation/Future.md) is a proxy of value that will be available at some point in the future. See example for advances of using futures.
    * [`Channel`](Documentation/Channel.md) is like a `Future` that may provide `Periodic` values before final one.
    * [`Executor`](Documentation/Executor.md) is object made to execute escaped block `(Void) -> Void`. Its propose is to encapsulate a way of an execution.
    * [`ExecutionContext`](Documentation/ExecutionContext.md) is a protocol concurrency-aware objects must conform to. It basically make them actors or components of actor.
    * [`Fallible`](Documentation/Fallible.md) is validation monad. Is an object that represents either success value of failure value (Error).
	* [`Cache`](Documentation/Cache.md) is a primitive that lets you coalesce requests and cache responses

## Using Futures

Let's assume that we have function that finds all prime numbers lesser then n

```swift
func primeNumbers(to n: Int) -> [Int] { /* ... */ }
```

#### Making future

```swift
let futurePrimeNumbers: Future<[Int]> = future { primeNumbers(to: 10_000_000) }
```

#### Applying transformation

```swift
let futureSquaredPrimeNumbers = futurePrimeNumbers
  .map { (primeNumbers) -> [Int] in
    return primeNumbers.map { (number) -> Int
      return number * number
    }
  }
```

#### Synchronously waiting for completion

```swift
if let fallibleNumbers = futurePrimeNumbers.wait(seconds: 1.0) {
  print("Number of prime numbers is \(fallibleNumbers.success?.count)")
} else {
  print("Did not calculate prime numbers yet")
}
```

#### Subscribing for completion

```swift
futurePrimeNumbers.onComplete { (falliblePrimeNumbers) in
  print("Number of prime numbers is \(falliblePrimeNumbers.success?.count)")
}
```

#### Combining futures

```swift
let futureA: Future<A> = /* ... */
let futureB: Future<B> = /* ... */
let futureC: Future<C> = /* ... */
let futureABC: Future<(A, B, C)> = zip(futureA, futureB, futureC)
```

#### Transition from callbacks-based flow to futures-based flow:

```swift
class MyService {
  /* implementation */
  
  func fetchPerson(withID personID: Person.Identifier) -> Future<Person> {
    let promise = Promise<Person>()
    self.fetchPerson(withID: personID, callback: promise.complete)
    return promise
  }
}
```

#### Transition from futures-based flow to callbacks-based flow

```swift
class MyService {
  /* implementation */
  
  func fetchPerson(withID personID: Person.Identifier,
                   callback: @escaping (Fallible<Person>) -> Void) {
    self.fetchPerson(withID: personID)
      .onComplete(block: callback)
  }
}
```

## Using Channels
Let's assume we have function that returns channel of prime numbers: sends prime numbers as finds them and sends number of found numbers as completion

```swift
func makeChannelOfPrimeNumbers(to n: Int) -> Channel<Int, Int> { /* ... */ }
```

#### Applying transformation

```swift
let channelOfSquaredPrimeNumbers = channelOfPrimeNumbers
  .mapPeriodic { (number) -> Int in
      return number * number
    }
```

#### Synchronously iterating over periodic values.

```swift
var primeNumbersIterator = channelOfPrimeNumbers.makeIterator()
while let number = primeNumbersIterator.next() {
  print(number)
}
```
*I would love to find out how to use for-loop, but I'm stuck with this.*

#### Synchronously waiting for completion

```swift
if let fallibleNumberOfPrimes = channelOfPrimeNumbers.wait(seconds: 1.0) {
  print("Number of prime numbers is \(fallibleNumberOfPrimes.success)")
} else {
  print("Did not calculate prime numbers yet")
}
```

#### Synchronously waiting for completion #2

```swift
let (primeNumbers, numberOfPrimeNumbers) = channelOfPrimeNumbers.waitForAll()
```

#### Subscribing for periodic

```swift
channelOfPrimeNumbers.onPeriodic { print("Periodic: \($0)") }
```

#### Subscribing for completion

```swift
channelOfPrimeNumbers.onComplete { print("Completed: \($0)") }
```

#### Making `Channel`

```swift
func makeChannelOfPrimeNumbers(to n: Int) -> Channel<Int, Int> {
  return channel { (sendPeriodic) -> Int in
    var numberOfPrimeNumbers = 0
    var isPrime = Array(repeating: true, count: n)

    for number in 2..<n where isPrime[number] {
      numberOfPrimeNumbers += 1
      sendPeriodic(number)

      // updating seive
      var seiveNumber = number + number
      while seiveNumber < n {
        isPrime[seiveNumber] = false
        seiveNumber += number
      }
    }

    return numberOfPrimeNumbers
  }
}
```

---

## Documentation

**Visit [CocoaPods website](http://cocoadocs.org/docsets/AsyncNinja/) for reference**

* [`Future`](Documentation/Future.md)
* [`Channel`](Documentation/Channel.md)
* [`Cache`](Documentation/Cache.md)
* [`Executor`](Documentation/Executor.md)
* [`ExecutionContext`](Documentation/ExecutionContext.md)
* [`Fallible`](Documentation/Fallible.md)
* [Actor Model](Documentation/ActorModel.md)
* [Memory Management](Documentation/MemoryManagement.md)
* [Integration](Documentation/Integration.md)

## Related Articles
* Moving to nice asynchronous Swift code
	* [GitHub](https://github.com/AsyncNinja/article-moving-to-nice-asynchronous-swift-code/blob/master/ARTICLE.md)
	* [Medium](https://medium.com/@AntonMironov/moving-to-nice-asynchronous-swift-code-7b0cb2eadde1)
