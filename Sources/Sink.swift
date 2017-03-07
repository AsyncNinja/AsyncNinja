//
//  Copyright (c) 2016-2017 Anton Mironov
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

import Dispatch

/// Is a `EventsDestination` you an only apply values to.
/// Very useful for write-only reactive properties (you can write to, but they are not observable) 
public class Sink<U, S>: EventsDestination {

  public typealias Update = U
  public typealias Success = S
  public typealias UpdateHandler = (_ sink: Sink<U, S>, _ event: ChannelEvent<Update, Success>, _ originalExecutor: Executor?) -> Void
  private let _updateHandler: UpdateHandler
  private let _updateExecutor: Executor
  private let _releasePool = ReleasePool()
  
  private var _locking = makeLocking()
  private var _isCompleted = false

  /// designated initializer
  public init(updateExecutor: Executor,
       updateHandler: @escaping UpdateHandler) {
    _updateHandler = updateHandler
    _updateExecutor = updateExecutor
  }

  /// Calls update handler
  public func update(
    _ update: Update,
    from originalExecutor: Executor? = nil) {
    _updateExecutor.execute(from: originalExecutor) {
      (originalExecutor) in
      self._updateHandler(self, .update(update), originalExecutor)
    }
  }

  /// Calls update handler
  public func tryComplete(
    _ completion: Fallible<Success>,
    from originalExecutor: Executor? = nil) -> Bool {
    
    _locking.lock()
    let didComplete = !_isCompleted
    _isCompleted = true
    _locking.unlock()
    
    if didComplete {
      _updateExecutor.execute(from: originalExecutor) {
        (originalExecutor) in
        self._updateHandler(self, .completion(completion), originalExecutor)
      }
    }
    
    return didComplete
  }

  /// **Internal use only**.
  public func _asyncNinja_insertToReleasePool(_ releasable: Releasable) {
    _releasePool.insert(releasable)
  }
  
  public func _asyncNinja_notifyCompletion(_ block: @escaping () -> Void) {
    _releasePool.notifyDrain(block)
  }
}
