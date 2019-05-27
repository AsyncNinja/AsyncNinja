//
//  EventSource_StartWith.swift
//  AsyncNinja
//
//  Created by Loki on 5/27/19.
//

import Foundation

extension EventSource {
  func startWith(_ update: Update, executor: Executor = Executor.default) -> Channel<Update,Success> {
    return startWith([update], executor: executor)
  }
  
  func startWith(_ updates: [Update], executor: Executor = Executor.default) -> Channel<Update,Success> {
    return producer(executor: Executor.default) { producer in
      updates.forEach() { producer.update($0, from: Executor.default) }
      self.bindEvents(producer)
    }
  }
}
