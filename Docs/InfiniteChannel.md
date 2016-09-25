# `InfiniteChannel`
This document describes concept and use of `InfiniteChannel`

##### Contents
**this topic is incomplete**

* [Concept](#concept)
	* [Why?](#why)
	* [Example](#example)

## Concept
`InfiniteChannel` represents values that periodically arrive. `InfiniteChannel ` oftenly represents events that appear one-by-one. For example:

* keyboard strokes can be treated as `InfiniteChannel<KeyStroke>`
* mouse clicks can be treated as `InfiniteChannel<Click>`
* requests that come to server as `InfiniteChannel<Request>`. From the client's point of view server may be treated as component that has input `InfiniteChannel<Request>` and output `InfiniteChannel<Response>`.

All of these events may infinitely arrive.
>	For events that may finish because of failure or with some meaningful result use [`Channel`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/Channel.md).

### Why?
* convenient
* declarative
* safe
* reactive approach

#### Example
```
let timerChannel = makeTimer(interval: interval)
	.filter { 0 == (random() % 4) }
	.onValue(context: context) { (context, _) in context.makeNoise() }
```
