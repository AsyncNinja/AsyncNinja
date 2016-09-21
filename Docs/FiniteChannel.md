# `FiniteChannel`
**this topic is incomplete**

This document describes concept and use of `FiniteChannel`

##### Contents
* [Concept](#concept)
	* [Why?](#why)

## Concept
`FiniteChannel` represents values that periodically arrive followed by failure of final value that completes `FiniteChannel`. `FiniteChannel` oftenly represents result of long running task that is not yet arrived and flow of some intermediate results. For Example:

* downloading file can be treated as `FiniteChannel<ProgressReport, URL>`
* cancellable flow of events can be treated as `FiniteChannel<Event, Void>`

### Why?
* convenient
* declarative
* safe
* reactive approach
