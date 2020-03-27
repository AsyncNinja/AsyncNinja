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

public typealias ES = EventSource

public extension ExecutionContext {
  // MARK: - combineLatest2
  /// Combines 2 recent updates into tuple
  /// You can pass custom executor or use default from Context
  func combineLatest<ES1:ES, ES2:ES>(_ es1: ES1, _ es2: ES2, executor: Executor? = nil)
    -> Channel<(ES1.Update,ES2.Update),(ES1.Success, ES2.Success)> {
      
      return CombineLatest2(es1, es2, executor: executor ?? self.executor)
        .retain(with: self)
        .producer
  }
  
  // MARK: - combineLatest3
  /// Combines recent 3 updates into tuple
  /// You can pass custom executor or use default from Context
  func combineLatest<ES1:ES, ES2:ES, ES3:ES>(_ es1: ES1, _ es2: ES2, _ es3: ES3, executor: Executor? = nil)
    -> Channel<(ES1.Update,ES2.Update,ES3.Update),(ES1.Success, ES2.Success, ES3.Success)> {
      
      return CombineLatest3(es1, es2, es3, executor: executor ?? self.executor)
        .retain(with: self)
        .producer
  }
  
  // MARK: - combineLatest4
  /// Combines recent 3 updates into tuple
  /// You can pass custom executor or use default from Context
  func combineLatest<ES1:ES, ES2:ES, ES3:ES, ES4:ES>(_ es1: ES1, _ es2: ES2, _ es3: ES3, _ es4: ES4, executor: Executor? = nil)
    -> Channel<(ES1.Update,ES2.Update,ES3.Update,ES4.Update),(ES1.Success, ES2.Success, ES3.Success, ES4.Success)> {
      
      return CombineLatest4(es1, es2, es3, es4, executor: executor ?? self.executor)
        .retain(with: self)
        .producer
  }
}

class RetainableProducerOwner<Update,Success> : ExecutionContext, ReleasePoolOwner {
  public let releasePool = ReleasePool()
  public var executor: Executor
  var producer = Producer<Update,Success>()
  
  
  init(executor: Executor) {
    self.executor = executor
  }
  
  func retain(with releasePool: Retainer) -> RetainableProducerOwner {
    releasePool.releaseOnDeinit(self)
    return self
  }
}


fileprivate class CombineLatest2<ES1:ES, ES2:ES> : RetainableProducerOwner<(ES1.Update, ES2.Update), (ES1.Success, ES2.Success)> {
  var update1 : ES1.Update?
  var update2 : ES2.Update?
  
  var success1 : ES1.Success?
  var success2 : ES2.Success?
  
  init(_ es1: ES1, _ es2: ES2, executor: Executor) {
    super.init(executor: executor)
    
    es1.onUpdate(context: self) { ctx, upd in     ctx.update1 = upd;      ctx.trySendUpdate() }
      .onSuccess(context: self) { ctx, success in ctx.success1 = success; ctx.tryComplete()   }
      .onFailure(context: self) { ctx, error in   ctx.producer.fail(error, from: executor) }
    
    es2.onUpdate(context: self) { ctx, upd in     ctx.update2 = upd;      ctx.trySendUpdate() }
      .onSuccess(context: self) { ctx, success in ctx.success2 = success; ctx.tryComplete()   }
      .onFailure(context: self) { ctx, error in   ctx.producer.fail(error, from: executor) }
  }
  
  func trySendUpdate() {
    guard let upd1 = update1 else { return }
    guard let upd2 = update2 else { return }
    
    producer.update((upd1,upd2), from: executor)
  }
  
  func tryComplete() {
    guard let suc1 = success1 else { return }
    guard let suc2 = success2 else { return }
  
    producer.succeed((suc1,suc2), from: executor)
  }
}

fileprivate class CombineLatest3<ES1:ES, ES2:ES, ES3:ES> : RetainableProducerOwner<(ES1.Update, ES2.Update, ES3.Update), (ES1.Success, ES2.Success, ES3.Success)> {
  var update1 : ES1.Update?
  var update2 : ES2.Update?
  var update3 : ES3.Update?
  
  var success1 : ES1.Success?
  var success2 : ES2.Success?
  var success3 : ES3.Success?
  
  init(_ es1: ES1, _ es2: ES2, _ es3: ES3, executor: Executor) {
    super.init(executor: executor)
    
    es1.onUpdate(context: self) { ctx, upd in     ctx.update1 = upd;      ctx.trySendUpdate() }
      .onSuccess(context: self) { ctx, success in ctx.success1 = success; ctx.tryComplete()   }
      .onFailure(context: self) { ctx, error in   ctx.producer.fail(error, from: executor) }
    
    es2.onUpdate(context: self) { ctx, upd in     ctx.update2 = upd;      ctx.trySendUpdate() }
      .onSuccess(context: self) { ctx, success in ctx.success2 = success; ctx.tryComplete()   }
      .onFailure(context: self) { ctx, error in   ctx.producer.fail(error, from: executor) }
    
    es3.onUpdate(context: self) { ctx, upd in     ctx.update3 = upd;      ctx.trySendUpdate() }
      .onSuccess(context: self) { ctx, success in ctx.success3 = success; ctx.tryComplete()   }
      .onFailure(context: self) { ctx, error in   ctx.producer.fail(error, from: executor) }
  }
  
  func trySendUpdate() {
    guard let upd1 = update1 else { return }
    guard let upd2 = update2 else { return }
    guard let upd3 = update3 else { return }
    
    producer.update((upd1,upd2,upd3), from: executor)
  }
  
  func tryComplete() {
    guard let suc1 = success1 else { return }
    guard let suc2 = success2 else { return }
    guard let suc3 = success3 else { return }
    
    producer.succeed((suc1,suc2,suc3), from: executor)
  }
}

fileprivate class CombineLatest4<ES1:ES, ES2:ES, ES3:ES, ES4:ES> : RetainableProducerOwner<(ES1.Update, ES2.Update, ES3.Update, ES4.Update), (ES1.Success, ES2.Success, ES3.Success, ES4.Success)> {
  var update1 : ES1.Update?
  var update2 : ES2.Update?
  var update3 : ES3.Update?
  var update4 : ES4.Update?
  
  var success1 : ES1.Success?
  var success2 : ES2.Success?
  var success3 : ES3.Success?
  var success4 : ES4.Success?
  
  init(_ es1: ES1, _ es2: ES2, _ es3: ES3, _ es4: ES4, executor: Executor) {
    super.init(executor: executor)
    
    es1.onUpdate(context: self) { ctx, upd in     ctx.update1 = upd;      ctx.trySendUpdate() }
      .onSuccess(context: self) { ctx, success in ctx.success1 = success; ctx.tryComplete()   }
      .onFailure(context: self) { ctx, error in   ctx.producer.fail(error, from: executor) }
    
    es2.onUpdate(context: self) { ctx, upd in     ctx.update2 = upd;      ctx.trySendUpdate() }
      .onSuccess(context: self) { ctx, success in ctx.success2 = success; ctx.tryComplete()   }
      .onFailure(context: self) { ctx, error in   ctx.producer.fail(error, from: executor) }
    
    es3.onUpdate(context: self) { ctx, upd in     ctx.update3 = upd;      ctx.trySendUpdate() }
      .onSuccess(context: self) { ctx, success in ctx.success3 = success; ctx.tryComplete()   }
      .onFailure(context: self) { ctx, error in   ctx.producer.fail(error, from: executor) }
    
    es4.onUpdate(context: self) { ctx, upd in     ctx.update4 = upd;      ctx.trySendUpdate() }
      .onSuccess(context: self) { ctx, success in ctx.success4 = success; ctx.tryComplete()   }
      .onFailure(context: self) { ctx, error in   ctx.producer.fail(error, from: executor) }
  }
  
  func trySendUpdate() {
    guard let upd1 = update1 else { return }
    guard let upd2 = update2 else { return }
    guard let upd3 = update3 else { return }
    guard let upd4 = update4 else { return }
    
    producer.update((upd1,upd2,upd3,upd4), from: executor)
  }
  
  func tryComplete() {
    guard let suc1 = success1 else { return }
    guard let suc2 = success2 else { return }
    guard let suc3 = success3 else { return }
    guard let suc4 = success4 else { return }
    
    producer.succeed((suc1,suc2,suc3,suc4), from: executor)
  }
}
