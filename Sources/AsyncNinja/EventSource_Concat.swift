//
//  Copyright (c) 2016-2020 Anton Mironov, Loki
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"),
//  to deal in the Software without restriction, including without limitation
//  the rights to use, copy, modify, merge, publish, distribute, sublicense,
//  and/or sell copies of the Software, and to permit persons to whom
//  the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
//  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
//  IN THE SOFTWARE.
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
            case .completion(let completion):
                switch completion {
                case .success(_):
                    self?.nextSource(dropFirst: true)
                case .failure(let error):
                    self?.producer.fail(error)
                }
                
            }
        }
    }
}
