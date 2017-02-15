#Memory Management

This topic recommends rules that help to avoid retain cycles between AsyncNinja abstractions (futures and Channels) and their host objects (actors and actor compoents).

##Rules
* use [Actor Model](ActorModel.md)
* use futures and Channels manipulation methods that has `context: ExecutionContext` argument

##How does it work?
Futures and Channels will be automaticaly deallocated as soon a you loose last reference to them or there are no subscribers to their values. Unless their completion is bound to context with methods `onComplete(context:block:)`, `onUpdate(context:block:)`, `onSuccess(context:block:)`, `onFailure(context:block:)`. Futures and Channels bound in such way will live as long as owning context lives.
