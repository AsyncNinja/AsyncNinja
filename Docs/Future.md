# `Future`
This document describes concept and use of `Future`.

##### Contents
*    [Concept](#Concept)
    *     [Implementation Details](#Implementation-Details)
    *    [Example: Solution based on callbacks](#Solution-based-on-callbacks)
    *     [Example: Solution based on futures](#Solution-based-on-futures)
*  [Reference](#Reference)
    *  [Creating `Future`](#Creating-Future)
    *  [Transforming `Future`](#Transforming-Future)
    *  [Combining `Future`s](#Combining-Futures)
    *  [Changing Mutable State with Future](#Changing-Mutable-State-with-Future)

##Concept
[As Wikipedia says](https://en.wikipedia.org/wiki/Futures_and_promises) `Future` is an object that acts as a proxy for a result that is initially unknown, usually because the computation of its value is yet incomplete. 

Straightforward solution will be using callback closure.
```
func perform(request: Request, callback: @escaping (Response) -> Void)
```

But this solution has multiple disadvantages:

*    so called ["callback hell"](http://callbackhell.com) or ["pyramid of doom"](https://en.wikipedia.org/wiki/Pyramid_of_doom_(programming))
*    combining multiple asynchronous operations is a complete disaster
*    it is hard to think of response as a result of operation because it placed inside function arguments
*    be very attentive to memory management within callback closure

Function declaration that incorporates `Future` will look like this:
```
func perform(request: Request) -> Future<Response>
```

Solutions based on `Future`

*    are shorter
*    you are getting something as returned value
*    are designed to be highly combinable
*     AsyncNinja's [memory management](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/MemoryManagement.md) helps to avoid majority of memory issues

#### Implementation Details
In oppose to other implementations future may not complete with an error by default. The combination of `Future<Fallible<T>>` must be used in order to have this feature (`FallibleFuture<T>` type alias is preferred).

#### Example

##### Solution based on callbacks

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

##### Solution based on futures

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

## Reference
### Creating `Future`

#### `Future` as a result of asynchronous operation
In most cases, initial future is a result of the asynchronous operation.

###### Simple
*    regular
    *    `func future<T>(executor: Executor, block: @escaping () -> T) -> Future<T>` 
*    [fallible](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Fallible.md)
    *     `func future<T>(executor: Executor, block: @escaping () throws -> T) -> FallibleFuture<T>`
*  [contextual](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/ExecutionContext.md
    *    `func future<T, U : ExecutionContext>(context: U, executor: AsyncNinja.Executor?, block: @escaping (U) throws -> T) -> FallibleFuture<T>`

###### Delayed
*    regular
    *  `func future<T>(executor: Executor, after timeout: Double, block: @escaping () -> T) -> Future<T>` 
*  [fallible](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Fallible.md)
    *  `func future<T>(executor: Executor, after timeout: Double, block: @escaping () throws -> T) -> FallibleFuture<T>`
*  [contextual](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/ExecutionContext.md)
    *  `func future<T, U : ExecutionContext>(context: U, executor: AsyncNinja.Executor?, after timeout: Double, block: @escaping (U) throws -> T) -> FallibleFuture<T>`

#### `Future` with predefined value
In some cases, it is convenient to make future with a predefined value.

*    regular
    *    `func future<T>(value: T) -> Future<T>`
*    [fallible](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Fallible.md)
    *    `func future<T>(success: T) -> FallibleFuture<T>`
    *     `func future<T>(failure: Error) -> FallibleFuture<T>`

#### `Promise`
`Promise` is a specific subclass of `Future` that can be instantiated with public initializer and can be manually completed with `func complete(with final: Value) -> Bool` and `func complete(with future: Future<Value>)`. `Promise` is useful when you have to manage completion manually. Bridging from API based on callbacks is a very common case of using `Promise`:

```
    func perform(request: Request) -> Future<Response> {
        let promise = Promise<Response>
        _oldAPI.perform(request: request) { [weak promise] in
            promise?.complete(with: $0)
        }
        return promise
    }
```

There is a specific kind of promise called `FalliblePromise` is promise with `Fallible` value type. It can be canceled manually.

### Transforming `Future`
Transform value when in becomes available into another value.

*    regular
    *    `func Future<Value>.map<T>(executor: Executor, transform: @escaping (Value) -> T) -> Future<T>`
*    [fallible](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Fallible.md)
    *    `func Future<Value>.map<T>(executor: Executor, transform: @escaping (Value) throws -> T) -> FallibleFuture<T>`
    *    `func Future<Value>.mapSuccess<T>(executor: Executor, transform: @escaping (Value.Success) throws -> T) -> FallibleFuture<T>`
    *    `func Future<Value>.mapFailure(executor: Executor, transform: @escaping (Error) -> Value.Success) -> Future<Value.Success>`
    *    `func Future<Value>.mapFailure(executor: Executor, transform: @escaping (Error) throws -> Value.Success) -> FallibleFuture<Value.Success> `
*    [contextual](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/ExecutionContext.md)
    *    `func Future<Value>.map<T, U: ExecutionContext>(context: U, executor: Executor? = nil,
transform: @escaping (U, Value) throws -> T) -> FallibleFuture<T>`
*    [contextual](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/ExecutionContext.md) and [fallible](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Fallible.md)
    *    `func Future<Value>.mapSuccess<T, U: ExecutionContext>(context: U, executor: Executor? = nil, transform: @escaping (U, Value.Success) throws -> T) -> FallibleFuture<T>`
    * `func Future<Value>.mapFailure<U: ExecutionContext>(context: U, executor: Executor? = nil, transform: @escaping (U, Error) throws -> Value.Success) -> FallibleFuture<Value.Success>`
*     delayed
    *  `delayed(timeout: Double) -> Future<Value>`


### Combining `Future`s
Sometimes there is a possibility to perform multiple independent operations and use combined results. AsyncNinja provides multiple ways to do this.

*    regular zipping few `Future`s with different value types
    *    `func zip<A, B>(_ futureA: Future<A>, _ futureB: Future<B>) -> Future<(A, B)>`
    *    `func zip<A, B, C>(_ futureA: Future<A>, _ futureB: Future<B>, _ futureC: Future<C>) -> Future<(A, B, C)>`
*    [fallible](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Fallible.md) zipping few `Future`s with different value types
    *    `func zip<A, B>(_ futureA: FallibleFuture<A>, _ futureB: FallibleFuture<B>) -> FalliblePromise<(A, B)>`
    *    `func zip<A, B, C>(_ futureA: FallibleFuture<A>, _ futureB: FallibleFuture<B>, _ futureC: FallibleFuture<C>) -> FallibleFuture<(A, B, C)>`
*    combining collection of `Future`s into single one
    *    regular
        *    `func Collection<Future<Value>>.joined() -> Future<[Value]>`
    *     [fallible](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Fallible.md)
        *  `func Collection<FallibleFuture<Value>>.joined() -> FallibleFuture<[Value]>`
*  reducing over collection of `Future`s into single `Future` of accumulated result
    *  regular
        *  `func Collection<Future<Value>>.reduce<Result>(executor: Executor, initialResult: Result, nextPartialResult: @escaping (Result, FinalValue) -> Result) -> Future<Result>`
    *  [fallible](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Fallible.md)
        *  `func Collection<Future<Value>>.reduce<Result>(executor: Executor, initialResult: Result, nextPartialResult: @escaping (Result, FinalValue) -> Result) -> Future<Result>`
        *  `func Collection<FallibleFuture<Value>>.reduce<Result>(executor: Executor, initialResult: Result, nextPartialResult: @escaping (Result, FinalValue) throws -> Result) -> FallibleFuture<Result>`
*  asynchrounously processing each element of collection and combining then unto a single `Future`
    *  `func Collection<Element>.asyncMap<T>(executor: Executor, ..., transform: (Element) -> T) -> Future<[T]>`
              

### Changing Mutable State with `Future`
After creation, transformations and combination of futures comes time to store results somewhere. In oppose to previous operations this operation is 100% impure. All of following operations are contextual because of [memory management](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/MemoryManagement.md) considerations.

*    `func Future<Value>.onValue<U: ExecutionContext>(context: U, block: @escaping (U, Value) -> Void)`
*    `func FallibleFuture<Success>.onSuccess<U: ExecutionContext>(context: U, block: @escaping (U, Success) -> Void)`
*    `func FallibleFuture<Success>.onFailure<U: ExecutionContext>(context: U, block: @escaping (U, Error) -> Void)` 