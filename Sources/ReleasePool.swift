//
//  Copyright (c) 2016 Anton Mironov
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

public typealias Releasable = Any

final public class ReleasePool {
  private let _tier1Container = makeThreadSafeContainer()
  private let _tier2Container = makeThreadSafeContainer()
  private let _tier3Container = makeThreadSafeContainer()
  static let numberOfItemsForTier2 = (1 << 12) - 1
  static let numberOfItemsForTier3 = (1 << 24) - 1

  public init() { }
  
  deinit {
    _tier1Container.updateHead { _ in return nil }
    _tier2Container.updateHead { _ in return nil }
    _tier3Container.updateHead { _ in return nil }
  }

  private func updateHead(_ block: (AnyObject?) -> AnyObject?) {
    guard let item = _tier1Container.updateHead(block).newHead as? Item
      else { return }
    
    if (item.index & ReleasePool.numberOfItemsForTier2) == ReleasePool.numberOfItemsForTier2 {
      _tier2Container.updateHead { NextTierItem(item: item, next: $0 as! NextTierItem?) }
    }

    if (item.index & ReleasePool.numberOfItemsForTier3) == ReleasePool.numberOfItemsForTier3 {
      _tier3Container.updateHead { NextTierItem(item: item, next: $0 as! NextTierItem?) }
    }
}
  
  public func insert(_ releasable: Releasable) {
    self.updateHead { ReleasableItem(object: releasable, next: $0 as! Item?) }
  }

  public func notifyDrain(_ block: @escaping () -> Void) {
    self.updateHead { NotifyItem(notifyBlock: block, next: $0 as! Item?) }
  }

  public func drain() {
    _tier1Container.updateHead { _ in return nil }
    _tier2Container.updateHead { _ in return nil }
    _tier3Container.updateHead { _ in return nil }
  }

  class Item {
    let next: Item?
    let index: Int

    init(next: Item?) {
      self.next = next
      self.index = next.flatMap { $0.index + 1 } ?? 0
    }
  }

  final class NotifyItem : Item {
    let notifyBlock: () -> Void

    init (notifyBlock: @escaping () -> Void, next: Item?) {
      self.notifyBlock = notifyBlock
      super.init(next: next)
    }

    deinit {
      self.notifyBlock()
    }
  }

  final class ReleasableItem : Item {
    let object: Releasable

    init(object: Releasable, next: Item?) {
      self.object = object
      super.init(next: next)
    }
  }
  
  final class NextTierItem {
    let item: Item
    let next: NextTierItem?
    init(item: Item, next: NextTierItem?) {
      self.item = item
      self.next = next
    }
  }
}
