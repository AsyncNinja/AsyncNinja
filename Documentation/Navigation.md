# Navigating in methods of `Future` and `Channel`

## Step 1: Pick a Kind of Reaction

| kind of reaction     | block to specify                                                                  | use case                                                         |
|----------------------|-----------------------------------------------------------------------------------|------------------------------------------------------------------|
| update state         | `(Result) -> Void`                *or* `(Context, Result) -> Void`                | update UI, update state of an actor, modify managed objects, ... |
| transfrom            | `(Result) -> Transformed`         *or* `(Context, Result) -> Transformed`         | transforming value                                               |
| flattening transform | `(Result) -> Future<Transformed>` *or* `(Context, Result) -> Future<Transformed>` | transforming value into future and flattening returned future    |

## Step 2: Pick the Case

| case         | success	| failure	| update	|   | `Future`	| `Channel`	|
|--------------|------------|-----------|-----------|---|-----------|-----------|
| on update    |      		|        	| ✅    		|   |        	| ✅       	|
| on success   | ✅     		|         	|         	|   | ✅     	| ✅       	|
| on failure   |         	| ✅      	|         	|   | ✅     	| ✅       	|
| on complete  | ✅      	| ✅      	|         	|   | ✅      	| ✅       	|
| on event     | ✅      	| ✅      	| ✅      	|   |         	| ✅       	|


## Step 3: Context Relation

| context relation | use case                                                                         | execution conditions |
|------------------|----------------------------------------------------------------------------------|----------------------|
| contextual       | obvious context is exists: service, view controller, managed object context, ... | context is alive     |
| non-contextual   | no obvious context                                                               | unconditional        |

## Step 4: Pick Method
You have chosen **kind of reaction**, **case**, **context relation**. Now navigate the table to find method you need.

|                      | case ➡️            	| on update                          | on success                        | on failure                     | on complete                          | on event                    |
|----------------------|--------------------|------------------------------------|-----------------------------------|--------------------------------|--------------------------------------|-----------------------------|
| kind of reaction ⬇  | is contextual ⬇   	| | | | | |
| `Future`             | `Future`          	| `Future`                           | `Future`                          | `Future`                       | `Future`                             | `Future`                    |
| update state         |                   	| -	                                 | `onSuccess(executor:block:)`      | `onFailure(executor:block:)`   | `onComplete(executor:block:)`        | -                           |
| transfrom            |                   	| -                                  | `map(executor:block:)`            | `recover(executor:block:)`     | `mapCompletion(executor:block:)`     | -                           |
| flattening transform |                   	| -                                  | `flatMap(executor:block:)`        | `flatRecover(executor:block:)` | `flatMapCompletion(executor:block:)` | -                           |
| `Future`             | `Future`          	| `Future`                           | `Future`                          | `Future`                       | `Future`                             | `Future`                    |
| update state         | ✅                	| -	                               	 | `onSuccess(context:block:)`       | `onFailure(context:block:)`    | `onComplete(context:block:)`         | -                           |
| transfrom            | ✅                	| -                                  | `map(context:block:)`             | `recover(context:block:)`      | `mapCompletion(context:block:)`      | -                           |
| flattening transform | ✅              	| -                                  | `flatMap(context:block:)`         | `flatRecover(context:block:)`  | `flatMapCompletion(context:block:)`  | -                           |
||||||||
| kind of reaction ⬇  | is contextual ⬇   	| | | | | |
| `Channel`            | `Channel`         	| `Channel`                          | `Channel`                         | `Channel`                      | `Channel`                            | `Channel`                   |
| update state         |                   	| `onUpdate(executor:block:)`        | `onSuccess(executor:block:)`      | `onFailure(executor:block:)`   | `onComplete(executor:block:)`        | `onEvent(executor:block:)`  |
| transfrom            |                   	| `map(executor:block:)`             | `mapSuccess(executor:block:)`     | `recover(executor:block:)`     | `mapCompletion(executor:block:)`     | `mapEvent(executor:block:)` |
| flattening transform |                   	| `flatMap(executor:block:)`         | `flatMapSuccess(executor:block:)` | `flatRecover(executor:block:)` | `flatMapCompletion(executor:block:)` | -                           |
| `Channel`            | `Channel`         	| `Channel`                          | `Channel`                         | `Channel`                      | `Channel`                            | `Channel`                   |
| update state         | ✅                 	| `onUpdate(context:block:)`         | `onSuccess(context:block:)`       | `onFailure(context:block:)`    | `onComplete(context:block:)`         | `onEvent(context:block:)`   |
| transfrom            | ✅                 	| `map(context:block:)`              | `mapSuccess(context:block:)`      | `recover(context:block:)`      | `mapCompletion(context:block:)`      | `mapEvent(context:block:)`  |
| flattening transform | ✅                 	| `flatMap(context:block:)`          | `flatMapSuccess(context:block:)`  | `flatRecover(context:block:)`  | `flatMapCompletion(context:block:)`  | -                           |


## No need to remember all of that
There is a rule of thumb for picking method: `<kind_of_reaction><case>(<context: or executor:>:, block:)`

| kind of reaction ⬇	| case ⬇	|
|-----------------------|-----------|
| **on** or **map** or **flatMap** | **Update** or **Successs** or **Failure** or **Completion** or **Event** |
