# 0.4.0-beta5
* zip of fallibles added

# 0.4.0-beta4
* improving unit tests
* fixing edge cases of memory management
* documentation improvements

# 0.4.0-beta3
* ActionChannels to NSControl and UIControl that catch actions and treat them as periodic values
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
