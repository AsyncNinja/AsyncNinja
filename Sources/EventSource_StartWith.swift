//
//  EventSource_StartWith.swift
//  AsyncNinja
//
//  Created by Loki on 5/27/19.
//

import Foundation

public extension EventSource {
  func startWith(_ update: Update, executor: Executor = Executor.default) -> Channel<Update,Success> {
    return startWith([update], executor: executor)
  }
  
  func startWith(_ updates: [Update], executor: Executor = Executor.default) -> Channel<Update,Success> {
    return producer(executor: Executor.default) { producer in
      updates.forEach() { producer.update($0, from: Executor.default) }
      self.bindEvents(producer)
    }
  }
  
  func withLatest<ES: EventSource>(from source: ES) -> Channel<(Update, ES.Update),Void> {
    let locking = makeLocking(isFair: true)
    let producer = Producer<(Update, ES.Update),Void>()
    var myUpdate     : Update? = nil
    var otherUpdate  : ES.Update? = nil
    
    source.onUpdate() { upd in
      locking.lock()
        if otherUpdate == nil && myUpdate == nil {
          if let myUpdate = myUpdate {
            producer.update((myUpdate,upd))
          }
        }
      otherUpdate = upd
      locking.unlock()
      }
      .onFailure() { producer.fail($0) }
      .onSuccess() { _ in producer.succeed() }
    
    let handler = self.makeHandler(executor: .default) { (event, _) in
      print("event \(event)")
      switch event {
        
      case let .update(upd):
        locking.lock()
        myUpdate = upd
        if let updOther = otherUpdate {
          producer.update((upd, updOther))
        }
        locking.unlock()
      case .completion(_):
        locking.lock()
        producer.succeed()
        locking.unlock()
      }
    }
    self._asyncNinja_retainHandlerUntilFinalization(handler)
    
    return producer
  }
}
