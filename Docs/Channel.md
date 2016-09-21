# `Channel`
This document describes concept and use of `Channel`

##### Contents
* [Concept][#concept]
	* [Why?][#why]
	* [Example][#example]

## Concept
`Channel` represents values that periodically arrive. `Channel` oftenly represents events that appear one-by-one. For example:

* keyboard strokes can be treated as `Channel<KeyStroke>`
* mouse clicks can be treated as `Channel<Click>`
* requests that come to server as `Channel<Request>`. From the client's point of view server may be treated as component that has input `Channel<Request>` and output `Channel<Response>`.

All of these events may infinitely arrive.
>	For events that may finish because of failure or with some meaningful result use [`FiniteChannel`](https://github.com/AsyncNinja/AsyncNinja/blob/master/Docs/FiniteChannel.md).

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