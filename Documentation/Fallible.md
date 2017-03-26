# `Fallible`
This document describes concept and use of `Fallible`.

**For class reference visit [CocoaPods](http://cocoadocs.org/docsets/AsyncNinja/1.0.0-beta7/Enums/Fallible.html).** 

##### Contents
*    [Concept](#concept)
    *    [`throws` vs. `Fallible`](#throws-vs-fallible)
    *     [Summary](#summary)
*    [Asynchronous Operations with Error Handling](#asynchronous-operations-with-error-handling)

## Concept
`Fallible` is a stuct that contains either success or failure.

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
