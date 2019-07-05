//
//  EventSource_Concat.swift
//  AsyncNinja
//
//  Created by Loki on 5/27/19.
//

import Foundation

public extension ExecutionContext {
    func concat<ES:EventSource>(sources: [ES], executor: Executor? = nil) -> Channel<ES.Update,Void> {
        return Concatenator(sources: sources, executor: executor ?? self.executor)
            .retain(with: self)
            .producer
    }
}

private class Concatenator<ES:EventSource> : RetainableProducerOwner<ES.Update,Void> {
    var sources: [ES]
    
    init(sources: [ES], executor: Executor){
        self.sources = sources
        super.init(executor: executor)
        
        nextSource(dropFirst: false)
    }
    
    func nextSource(dropFirst : Bool ) {
        if dropFirst {
            sources.removeFirst()
        }
        
        guard sources.count > 0 else {
            producer.succeed(from: executor)
            return
        }
        
        susbscribe(to: sources.first!)
    }
    
    func susbscribe(to source: ES) {
        source.onEvent(executor: executor) { [weak self] event in
            switch event {
            case .update(let upd):
                self?.producer.update(upd, from: self!.executor)
            case .completion(_):
                self?.nextSource(dropFirst: true)
            }
        }
    }
}
