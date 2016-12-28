# 0.3.7
* fix: cancellation check in convenience methods of `URLSession`
* a bit of documentation about `Cache` added
* more convincing readme

# 0.3.6
* fix: `Channel` can callback on `onPeriodic` two times for first periodic
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