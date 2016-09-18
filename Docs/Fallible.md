# `Fallible`

`Fallible` is a box that contains either success or failure.

##### Contents
*    [Concept](#Concept)
    *    [`throws` vs. `Fallible`](#throws-vs-Fallible)
    *     [Summary](#Summary)
*    [Reference](#Reference)
    *    [Creating `Fallible`](#Creating-Fallible)
    *     [Transforming `Fallible`](#Transforming-Fallible)
    *  [Unwrapping `Fallible`](#Unwrapping-Fallible)
*    [Asynchronous Operations with Error Handling](#Asynchronous-Operations-with-Error-Handling)

## Concept

###### Simplified implementation
```
enum Fallible<T> {
  case success(T)
  case failure(Error)
} 
``` 

`Fallible` is AsyncNinja's implementation of validation monad.
###  `throws` vs. `Fallible`

##### `throws` is great because...

*    you can throw whenever you want

```
func perform(request: Request) throws -> Response {
    guard isValid(request)    else { throw LocalError.InvalidRequest }
    ...
}
```

##### `throws` is not so great because...

*    error recovery is clunky

```
func perform(request: Request) throws -> Response { ... }

    ...
    let response: Response
    do {
        response = try perform(request: request)
    } catch {
        response = Response(error: error)
    }
    ...
```

*    you cannot asynchronously throw *(yet ?)*

```
    /* You just cannot */
```


##### `Fallible` is great because...

*    error recovery is short

```
func perform(request: Request) throws -> Response { ... }

    ...
    let response = fallible { try perform(request: request) }
        .mapFailure(Response.init(error:))
    ...
```

##### `Fallible` is not so great because...
*    you cannot finish function execution whenever you want

```
    /* You just cannot */
```
### Summary
Both approaches have their advantages and disadvantages. After consideration and multiple experiments, I've made a cheat sheet that describes when and what to use.

##### Cheat Sheet
|When|What|
|:--:|:--:|
|Synchrounous Execution|`throws`|
|Asynchrouhous Execution|`Fallible`|

## Reference

### Creating `Fallible`

#### with `init`
*    `Fallible<Success>.init(success: Success)`
*    `Fallible<Success>.init(failure: Error)`

#### from function with `throws`
*    `func fallible<Success>(block: () throws -> T) -> Fallible<Success>`

### Transforming `Fallible`

*    `func Fallible<Success>.mapSuccess<T>(transform: (Success) throws -> T) -> Fallible<T>`
*    `func Fallible<Success>.mapSuccess<T>(transform: (Success) throws -> Fallible<T>) -> Fallible<T>`
*    `func Fallible<Success>.mapFailure(transform: (Error) throws -> Success) -> Fallible<Success>`
*    **failure recovery**
    `func Fallible<Success>.mapFailure(transform: (Error) -> Success) -> Success`
    
### Unwrapping `Fallible`    

#### using properties
*    `var Fallible<Success>.success: Success? { get }`
*    `var Fallible<Success>.failure: Error? { get }`

#### using closures
*    `func Fallible<Success>.onSuccess(_ handler: (Success) throws -> Void) rethrows`
*    `func Fallible<Success>.onFailure(_ handler: (Error) throws -> Void) rethrows`

#### using function that `throws`

*    `func Fallible<Success>.liftSuccess() throws -> Success`

## Asynchronous Operations with Error Handling
`Fallible` is most useful in asynchronous execution (see [Cheet Sheet](#Cheet-Sheet)). The first asynchronous primitive of AsyncNinja is `Future`. Combining `Future` and `Fallible` gives us **asynchronous operations with error handling** with `Future<Fallible<T>>` (or simply `FallibleFuture<T>`).

#### Example

```
func perform(request: Request) throws -> Response { ... }

func performAsync(request: Request) -> Response {
    return future { perform(reqeust: request) }
        .mapFailure(Response.init(error:))
}

```