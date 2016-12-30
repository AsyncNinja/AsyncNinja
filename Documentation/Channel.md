# `Channel`
This document describes concept and use of `Channel`.

**For class reference visit [CocoaPods](http://cocoadocs.org/docsets/AsyncNinja/0.4/Classes/Channel.html).**

##### Contents
* [Concept](#concept)
	* [Why?](#why)

## Concept
`Channel` represents values that periodically arrive followed by failure of final value that completes `Channel`. `Channel` oftenly represents result of long running task that is not yet arrived and flow of some intermediate results. For Example:

* downloading file can be treated as `Channel<ProgressReport, URL>`
* cancellable flow of events can be treated as `Channel<Event, Void>`

### Why?
* convenient
* declarative
* safe
* reactive approach
