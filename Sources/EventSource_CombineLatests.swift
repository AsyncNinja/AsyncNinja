//
//  EventSource_CombineLatests.swift
//  AsyncNinja
//
//  Created by Loki on 5/23/19.
//

import Foundation

typealias ES = EventSource

func combineLatestUpdates<ES1:ES, ES2:ES>(_ es1: ES1, _ es2: ES2, executor: Executor = Executor.main)
  -> Channel<(ES1.Update,ES2.Update),(ES1.Success, ES2.Success)> {
  let combine = CombineLatest2(es1, es2, executor: executor)
  
  combine.producer._asyncNinja_retainHandlerUntilFinalization(combine)
  combine.producer._asyncNinja_notifyFinalization { print("combineLatestUpdates Finalization") }
  
  return combine.producer
}

fileprivate class CombineLatest2<ES1:ES, ES2:ES> : ExecutionContext, ReleasePoolOwner {
  typealias ResultUpdate  = (ES1.Update,  ES2.Update)
  typealias ResultSuccess = (ES1.Success, ES2.Success)
  
  public let releasePool = ReleasePool()
  public var executor: Executor
  
  var update1 : ES1.Update?
  var update2 : ES2.Update?
  
  var success1 : ES1.Success?
  var success2 : ES2.Success?
  
  let producer = Producer<ResultUpdate,ResultSuccess>()
  
  init(_ es1: ES1, _ es2: ES2, executor: Executor) {
    self.executor = executor
    
    producer._asyncNinja_retainUntilFinalization(self)
    
    es1.onUpdate(context: self) { ctx, upd in     ctx.update1 = upd;      ctx.trySendUpdate() }
      .onSuccess(context: self) { ctx, success in ctx.success1 = success; ctx.tryComplete()   }
      .onFailure(context: self) { ctx, error in   ctx.producer.fail(error) }
    
    es2.onUpdate(context: self) { ctx, upd in     ctx.update2 = upd;      ctx.trySendUpdate() }
      .onSuccess(context: self) { ctx, success in ctx.success2 = success; ctx.tryComplete()   }
      .onFailure(context: self) { ctx, error in   ctx.producer.fail(error) }
  }
  
  func trySendUpdate() {
    guard let upd1 = update1 else { return }
    guard let upd2 = update2 else { return }
    
    producer.update((upd1,upd2))
  }
  
  func tryComplete() {
    guard let suc1 = success1 else { return }
    guard let suc2 = success2 else { return }
  
    producer.succeed((suc1,suc2), from: executor)
  }
}
