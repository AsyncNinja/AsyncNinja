# `Fallible`

`Fallible` is a box that contains either success or failure.

##### Contents
*    [Concept](#concept)
    *    [`throws` vs. `Fallible`](#throws-vs-fallible)
    *     [Summary](#summary)
*    [Reference](#reference)
    *    [Creating `Fallible`](#creating-fallible)
    *     [Transforming `Fallible`](#transforming-fallible)
    *  [Unwrapping `Fallible`](#unwrapping-fallible)
*    [Asynchronous Operations with Error Handling](#asynchronous-operations-with-error-handling)

## Concept

###### Simplified implementation
```swift
enum Fallible<T> {
  case success(T)
  case failure(Swift.Error)
} 
``` 

`Fallible` is AsyncNinja's implementation of validation monad.
###  `throws` vs. `Fallible`

##### `throws` is great because...

*    you can throw whenever you want

```swift
func perform(request: Request) throws -> Response {
  guard isValid(request)
    else { throw LocalError.InvalidRequest }
    ...
}
```

##### `throws` is not so great because...

*    error recovery is clunky

```swift
func perform(request: Request) throws -> Response { ... }
  /* ... */
  
  let response: Response
  do {
    response = try perform(request: request)
  } catch {
    response = Response(error: error)
  }
  
  /* ... */
```

*    you cannot asynchronously throw *(yet ?)*

```swift
    /* You just cannot */
```


##### `Fallible` is great because...

*    error recovery is short

```swift
func perform(request: Request) throws -> Response { ... }

  /* ... */
  let response = fallible { try perform(request: request) }
    .recover(Response.init(error:))
  /* ... */
```

##### `Fallible` is not so great because...
*    you cannot finish function execution whenever you want

```swift
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
```swift
Fallible<Success>.init(success: Success)
Fallible<Success>.init(failure: Swift.Error)
```

#### from function with `throws`
```swift
func fallible<Success>(block: () throws -> T) -> Fallible<Success>
```

### Transforming `Fallible`

```swift
extension Fallible {
  func map<T>(transform: (Success) throws -> T) -> Fallible<T>
  func flatMap<T>(transform: (Success) throws -> Fallible<T>) -> Fallible<T>
  func recover(transform: (Swift.Error) throws -> Success) -> Fallible<Success>

  /* failure recovery */
  func recover(transform: (Swift.Error) -> Success) -> Success
```
    
### Unwrapping `Fallible`    

#### using properties
```swift
extension Fallible {
  var success: Success? { get }
  var .failure: Swift.Error? { get }
```

#### using closures
```swift
extension Fallible {
  func onSuccess(_ handler: (Success) throws -> Void) rethrows
  func onFailure(_ handler: (Swift.Error) throws -> Void) rethrows
}
```

#### using function that `throws`

```swift
extension Fallible {
  func Fallible<Success>.liftSuccess() throws -> Success
```

## Asynchronous Operations with Error Handling
`Fallible` is most useful in asynchronous execution (see [Cheat Sheet](#cheat-sheet)). The first asynchronous primitive of AsyncNinja is `Future`. `Future` completion value is `Fallible`. It means that every `Future` can either succeed or fail.

#### Example

```swift
func perform(request: Request) throws -> Response { ... }

func performAsync(request: Request) -> Response {
  return future { perform(reqeust: request) }
    .recover(Response.init(error:))
}

```
