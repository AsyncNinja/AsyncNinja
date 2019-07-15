//
//  EventSource_ifEmpty.swift
//  AsyncNinja
//
//  Created by Loki on 7/15/19.
//

import Foundation

public extension EventSource {
  func ifEmpty(switchTo other: Self, executor: Executor = .default) -> Channel<Update,Success> {
    
    let producer = Producer<Self.Update,Self.Success>()
    var updateCounter = 0
    
    let handler = self.makeHandler(executor: executor) { event, executor in
      switch event {
      
      case .update(let upd):
        updateCounter += 1
        producer.update(upd)
        
      case .completion(let comp):
        if updateCounter > 0 {
          producer.complete(comp)
        } else {
          other.bindEvents(producer)
        }
      }
    }
    
    self._asyncNinja_retainHandlerUntilFinalization(handler)
    
    return producer
  }
}
