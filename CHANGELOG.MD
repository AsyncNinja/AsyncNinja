# 1.2.4
* [gardening] fixed multiple warnings

# 1.2.3
* [performance] `Future` and `Promise` performance degradation detected. Performance fixed and improved

# 1.2.2
* [improved] internal implementation of linked list
* [fixed] compatibility [issue SR-5998](https://bugs.swift.org/browse/SR-5998) revealed by [improvement of type checker](https://github.com/apple/swift/pull/12072)

# 1.2.1
* [changed] `DispatchSemaphore`-based fair locking replaced with `pthread_mutex_t`-based locking
* [improved] code style improved with [SwiftLint](https://github.com/realm/SwiftLint) (once again)

# 1.2.0
* [changed] lock-free implementation of `Future` and `CancellationToken` changed to regular locking-based
* [fixed] multiple Xcode 9.0 beta 5 compile time issues

# 1.1.3
* [added] documentation generation infrastructure
* [added] primitive subscription chaining (`future.onSuccess { /* handle success */ }.onFailure { /* handle failure */ }`)
* [improved] parallel CI jobs
* [improved] `Promise` internals updated
* [fixed] warnings and erros introduced by Swift 4 toolchain

# 1.1.2
* [improved] compile time
* [improved] code style improved with [SwiftLint](https://github.com/realm/SwiftLint)

# 1.1.1
* [added] network reachability
* [improved] travis-ci config
* [fixed] potential leak of handlers in `Promise`
* [fixed] EventSource.first
* [fixed] EventSource.last
* [fixed] multiple flaky unit tests

# 1.1.0
* try execute methods added. They provide an ability to retry async execution multiple times
* convenience initializers for `Executor` added alongside with constructors to reduce confusion in some cases
* EventSource.skip implemented
* EventSource.take implemented
* EventSource.contains implemented
* EventSource.suspendable implemented

# 1.0.0
* better test coverage
* `CancellationToken` fixed and improved

# 1.0.0-beta7
* `staticCast` for `Future` and `Channel` added
* future to channel and channel to future transformations added
* `Cache` and `CachableValue` convenience initializers improved
* fixing major issue with `asyncMap()`, `asyncFlatMap()`, `asyncReduce()`, `joined()`
* fixing issue with inconsistent lifetime of the `Future` returned from contextual transformation of `Completing`
* adding ability to denote transformation as impure an apply different lifetime management for transformations
* documentation improved
* `TimerChannel` refactored to improve quality of implementation and to add flexibility

# 1.0.0-beta6
* documentation updated
* `Cache` and `CachedValue` improved
* `URLSession` extensions updated
* `Future.flatMap` improved
* `Channel.extractAll()` refactored to provide `Future<(updates: [Update], completion: Fallible<Success>)>`
* `Channel.waitForAll()` refactored and extended
* Major fixes of `Cache` and `CachableValue`
* Carthage support

# 1.0.0-beta5
* adding ability to nest synchronously calls on the same executor instead of making async dispatches all the time
* naming improved
* infrastructure build up on protocols has been build
* major reactive programming improvements: `ReactiveProperties`, convenience extensions added to most popular iOS controls, bindings added
* `Sink`, `DynamicProperty`, `ProducerProxy` added
* fixing and improving memory management/lifetime management of `Channel`

# 1.0.0-beta4
* x32 targets fixed
* `ProducerProxy` added
* binding `Channel` to `ProducerProxy` added
* more generic `Channel.distinct()` added

# 1.0.0-beta3
* improvements using `OptionalAdaptor`
* fixed locking within `CachableValue`
* fixes of `ObjCInjectedRetainer`
* adding unwrapping methods to `Future` and `Channel`
* making more obvious behavior of Channel.flatMap a default one
* introducing `ObservationSession` that helps to enable and disable multiple observations in a convenient way. This is very useful for enabling and disabling observation within `viewWillAppear` and `viewDidDisappear`

# 1.0.0-beta2
* continue renaming
* adding convenience methods for making completed futures and channels
* adding convenience `typealias Updating<T> = Channel<T, Void>`, `typealias Updatable<>T = Producer<T, Void>`
* adding OptionalAdaptor that helps to add methods for primitives parametrized with optionals

# 1.0.0-beta
* major renaming has been done. Using more consistent names

# 0.4.5
* adding 5 various behaviors to flatMap that transforms update to future
* adding descriptions (`CustomStringConvertible`, `CustomDebugStringConvertible`) for `Channel`, `Future`, `Fallible`, `Either`
* introducing multirun tests in order to fix flaky tests
* `Channel` is now `Sequence`
* fixes of `Channel`

# 0.4.4
* fixing issues in `ReleasePool` and `Channel`
* improving performace

# 0.4.3
* fixing code style
* adding `reduce(::)` method to channel
* convenience method for leaving group
* fixing `asyncMap`s and improving tests
* fixing compatibility with current swift master

# 0.4.2
* taking advantage of ability to make derived serial executor in order to avoid using locks
* operations on channels added: first(where:), last(where:), zip(_:, _:)
* fixing rare issue that could cause early releases of instances that depend on futures and channels

# 0.4.1
* putting back xcodeproj
* fixing documentation references

# 0.4.0
* documentation improved
* zip of fallibles added
* operation on channels: merge, sample, debounce
* better tests

# 0.4.0-beta4
* improving unit tests
* fixing edge cases of memory management
* documentation improvements

# 0.4.0-beta3
* ActionChannels to NSControl and UIControl that catch actions and treat them as update values
* turning down performance tests
* fixing critical issues of lifetime of `Future`s and `Channel`s

# 0.4-beta2
* AsyncNinja was turned back to a single module structure: no need for objc any more

# 0.4-beta1
* AsyncNinja was split into multiple modules
* previously deprecated `Pipe` was removed: use `Channel` with iterators instead
* making key-value observing channel added

# 0.3.7
* fix: cancellation check in convenience methods of `URLSession`
* a bit of documentation about `Cache` added
* more convincing readme

# 0.3.6
* fix: `Channel` can callback on `onUpdate` two times for first update
* fix: non-contextual `on<Event>` assertion failure

# 0.3.5
* better readme and documentation
* default buffer size of `Producer` changed to 1

# 0.3.4
* better documentation
* adding implicit documentation
* fixes of flaky tests
* deprecating `Pipe`: use `Channel` with iterators instead

# 0.3.3
* support of CocoaPods added
* travis integration
* better documentation
* fixes of flaky tests
* fixing poorly named methods

# 0.3.2
* better documentation
* improving methods that defer
* improving methods that flatten
* non-contextual `on<Event>` methods added to `Future` and `Channel`

# 0.3.1
* `ConstantChannel` (implementation of `Channel` with predefined values) disabled
* more convenience methods
* more tests

# 0.3
* `Channel`
	* non-draft
	* buffering (our solution for hot/cold channels)
	* synchronous iteration
* `InfiniteChannel` removed
* `Cache` (draft)
* performance improvements
* more tests

# 0.2

* `Pipe` [draft] primitive added
* renamed primitives
	* `Channel` -> `InfiniteChannel`
	* `FiniteChannel` -> `Channel`
* pore transformers
* performance improvements
* primitives lifetime fixes
* more tests

# 0.1

* Available primitives:
	* `Future`
	* `Channel` (draft)
	* `FiniteChannel` (draft)
	* `Fallible`
	* `Executor`
	* `ExecutionContext`
* Initial implementation
