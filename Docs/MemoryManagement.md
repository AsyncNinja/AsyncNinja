#Memory Management

This topic recommends rules that help to avoid retain cycles between AsyncNinja abstractions (futures and channels) and their host objects (actors and actor compoents).

##Rules
* use [Actor Model](ActorModel.md)
* use futures and channels manipulation methods that has `context: ExecutionContext` argument

##How does it work?
Futures and channels will be automaticaly deallocated as soon a you loose last reference to them or there are no subscribers to their values. Unless their completion is bound to context with methods `onFinal(context:block:)`, `onPeriodic(context:block:)`, `onSuccess(context:block:)`, `onFailure(context:block:)`. Futures and channels bound in such way will live as long as owning context lives.
