# Navigating in methods of `Future` and `Channel`

## Step 1: Pick a Kind of Reaction

| kind of reaction     | block to specify                                                                  | use case                                                         |
|----------------------|-----------------------------------------------------------------------------------|------------------------------------------------------------------|
| update state         | `(Result) -> Void`                *or* `(Context, Result) -> Void`                | update UI, update state of an actor, modify managed objects, ... |
| transfrom            | `(Result) -> Transformed`         *or* `(Context, Result) -> Transformed`         | transforming value                                               |
| flattening transform | `(Result) -> Future<Transformed>` *or* `(Context, Result) -> Future<Transformed>` | transforming value into future and flattening returned future    |

## Step 2: Pick the Case

| case         | success | failure | periodic |   | `Future` | `Channel` |
|--------------|---------|---------|----------|---|----------|-----------|
| on periodic  |         |         | ✅       |   |          | ✅        |
| on success   | ✅      |         |          |   | ✅       | ✅        |
| on failure   |         | ✅      |          |   | ✅       | ✅        |
| on complete  | ✅      | ✅      |          |   | ✅       | ✅        |
| on value     | ✅      | ✅      | ✅       |   |          | ✅        |


## Step 3: Context Relation

| context relation | use case                                                                         | execution conditions |
|------------------|----------------------------------------------------------------------------------|----------------------|
| contextual       | obvious context is exists: service, view controller, managed object context, ... | context is alive     |
| non-contextual   | no obvious context                                                               | unconditional        |

## Step 4: Pick Method
You have chosen **kind of reaction**, **case**, **context relation**. Now navigate the table to find method you need.

|                      | case ➡️            	| on periodic                        | on success                        | on failure                     | on complete                          | on value                   |
|----------------------|--------------------|------------------------------------|-----------------------------------|--------------------------------|--------------------------------------|----------------------------|
| kind of reaction ⬇  | is contextual ⬇   	| | | | | |
| `Future`             | `Future`          	| `Future`                           | `Future`                          | `Future`                       | `Future`                             | `Future`                   |
| update state         |                   	| -	                                 | `onSuccess(executor:block:)`      | `onFailure(executor:block:)`   | `onComplete(executor:block:)`        | -                          |
| transfrom            |                   	| -                                  | `map(executor:block:)`            | `recover(executor:block:)`     | `mapCompletion(executor:block:)`     | -                          |
| flattening transform |                   	| -                                  | `flatMap(executor:block:)`        | `flatRecover(executor:block:)` | `flatMapCompletion(executor:block:)` | -                          |
| `Future`             | `Future`          	| `Future`                           | `Future`                          | `Future`                       | `Future`                             | `Future`                   |
| update state         | ✅                	| -	                               	 | `onSuccess(context:block:)`       | `onFailure(context:block:)`    | `onComplete(context:block:)`         | -                          |
| transfrom            | ✅                	| -                                  | `map(context:block:)`             | `recover(context:block:)`      | `mapCompletion(context:block:)`      | -                          |
| flattening transform | ✅              	| -                                  | `flatMap(context:block:)`         | `flatRecover(context:block:)`  | `flatMapCompletion(context:block:)`  | -                          |
||||||||
| kind of reaction ⬇  | is contextual ⬇   	| | | | | |
| `Channel`            | `Channel`         	| `Channel`                          | `Channel`                         | `Channel`                      | `Channel`                            | `Channel`                  |
| update state         |                   	| `onPeriodic(executor:block:)`      | `onSuccess(executor:block:)`      | `onFailure(executor:block:)`   | `onComplete(executor:block:)`        | `onValue(executor:block:)` |
| transfrom            |                   	| `mapPeriodic(executor:block:)`     | `mapSuccess(executor:block:)`     | `recover(executor:block:)`     | `mapCompletion(executor:block:)`     | `map(executor:block:)`     |
| flattening transform |                   	| `flatMapPeriodic(executor:block:)` | `flatMapSuccess(executor:block:)` | `flatRecover(executor:block:)` | `flatMapCompletion(executor:block:)` | -                          |
| `Channel`            | `Channel`         	| `Channel`                          | `Channel`                         | `Channel`                      | `Channel`                            | `Channel`                  |
| update state         | ✅                 	| `onPeriodic(context:block:)`       | `onSuccess(context:block:)`       | `onFailure(context:block:)`    | `onComplete(context:block:)`         | `onValue(context:block:)`  |
| transfrom            | ✅                 	| `mapPeriodic(context:block:)`      | `mapSuccess(context:block:)`      | `recover(context:block:)`      | `mapCompletion(context:block:)`      | `map(context:block:)`      |
| flattening transform | ✅                 	| `flatMapPeriodic(context:block:)`  | `flatMapSuccess(context:block:)`  | `flatRecover(context:block:)`  | `flatMapCompletion(context:block:)`  | -                          |


## No need to remember all of that
There is a rule of thumb for picking method: `<kind_of_reaction><case>(<context: or executor:>:, block:)`

| kind of reaction ⬇	| case ⬇	|
|-----------------------|-----------|
| **on** or **map** or **flatMap** | **Periodic** or **Successs** or **Failure** or **Completion** or **Value** |
