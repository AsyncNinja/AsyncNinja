# `Removed Things`
This document describes things that were removed and reasoning for that.

##### Contents
**this topic is incomplete**

* [Not Fallible by Default](#not-fallible-by-default)
* [InfiniteChannel](#infinitechannel)
* [Making Derived Serial Executor](#making-derived-serial-executor)

## Not Fallible by Default
From the very beginning `Future`s could not fail by default.  You could combine `Future<Fallible<T>>` to achieve fallible behavior instead.  This idea felt good for a long time, but it introduced so much complexity.  Besides, this idea did not have much use on real-world applications. So it was removed to reduce complexity of both implementation and understanding of library.

## InfiniteChannel
`InfiniteChannel` seemed like a great idea too. If you have an infinite stream of events - use `InfiniteChannel`. Unfortunately it has to be removed for the same reasons as the previous one: too much complexity, too little use.   

## Making Derived Serial Executor
Making derived serial executor for a simple cases of synchronization sounded like a good idea at first. Unfortunately, in practice it was mostly involved in synchronizing too much and too soon.