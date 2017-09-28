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

class SinglyLinkedListImpl<Node: SinglyLinkedListElementNode>: Sequence {
  typealias Iterator = SinglyLinkedListIterator<Node>
  typealias Element = Node.Element

  private var _frontNode: Node?
  private var _backNode: Node?
  private(set) var count = 0
  var front: Element? { return _frontNode?.element }
  var back: Element? { return _backNode?.element }
  var isEmpty: Bool { return _frontNode.isNone }

  init() { }
  deinit {
    if count > 1000 {
      var node_ = _frontNode
      while let node = node_ {
        (node_, node.next) = (node.next, nil)
      }
    }
  }

  required init<N>(proto: SinglyLinkedListImpl<N>) where N.Element == Element {}

  func makeIterator() -> Iterator {
    return Iterator(node: _frontNode)
  }

  func pushFront(_ element: Element) {
    let newFrontNode = Node(element: element)
    if let oldFrontNode = _frontNode {
      newFrontNode.next = oldFrontNode
    } else {
      _backNode = newFrontNode
    }
    _frontNode = newFrontNode
    count += 1
  }

  func pushFront<S: Sequence>(_ elements: S) where S.Iterator.Element == Element {
    elements.forEach(pushFront)
  }

  func pushBack(_ element: Element) {
    let newBackNode = Node(element: element)
    if let oldBackNode = _backNode {
      oldBackNode.next = newBackNode
    } else {
      _frontNode = newBackNode
    }
    _backNode = newBackNode
    count += 1
  }

  func pushBack<S: Sequence>(_ elements: S) where S.Iterator.Element == Element {
    elements.forEach(pushBack)
  }

  func popFront() -> Element? {
    guard let frontNode = _frontNode else { return nil }
    if let nextFrontNode = frontNode.next {
      _frontNode = nextFrontNode
    } else {
      _frontNode = nil
      _backNode = nil
    }

    count -= 1
    return frontNode.element
  }

  func clone() -> Self {
    return type(of: self).init(proto: self)
  }

  func forEach(_ body: (Node.Element) throws -> Void) rethrows {
    var currentNode = _frontNode
    while let node = currentNode {
      currentNode = node.next
      try body(node.element)
    }
  }

  func enumerateAndValidate(_ block: (Element) -> Bool) {
    var currentNode = _frontNode
    var previousNode: Node?
    while let node = currentNode {
      currentNode = node.next
      if block(node.element) {
        previousNode = node
        continue
      }

      if let previousNode = previousNode {
        previousNode.next = currentNode
      } else {
        _frontNode = currentNode
      }
      count -= 1
    }
  }
}

// MARK: Nodes

protocol SinglyLinkedListElementNode: class {
  associatedtype Element

  var element: Element { get }
  var next: Self? { get set }

  init(element: Element)
}

final class SinglyLinkedListStrongElementNode<Element>: SinglyLinkedListElementNode {
  let element: Element
  var next: SinglyLinkedListStrongElementNode<Element>?

  required init(element: Element) {
    self.element = element
  }
}

final class SinglyLinkedListWeakElementNode<T: AnyObject>: SinglyLinkedListElementNode {
  typealias Element = T?
  private weak var _element: T?
  var element: Element { return _element }
  var next: SinglyLinkedListWeakElementNode<T>?

  required init(element: Element) {
    _element = element
  }
}

// MARK: - Iterator

struct SinglyLinkedListIterator<Node: SinglyLinkedListElementNode>: IteratorProtocol {
  private var _node: Node?

  init(node: Node?) {
    _node = node
  }

  mutating func next() -> Node.Element? {
    if let node = _node {
      _node = node.next
      return node.element
    } else {
      return nil
    }
  }
}

// MARK: -

protocol SinglyLinkedListBased {
  associatedtype Node: SinglyLinkedListElementNode
  var _impl: SinglyLinkedListImpl<Node> { get set }

  init()
  mutating func pop() -> Node.Element?
}

extension SinglyLinkedListBased {
  var first: Node.Element? { return _impl.front }
  var last: Node.Element? { return _impl.back }
  var count: Int { return _impl.count }
  var isEmpty: Bool { return _impl.isEmpty }

  mutating func pop() -> Node.Element? {
    if !isKnownUniquelyReferenced(&_impl) {
      _impl = SinglyLinkedListImpl(proto: _impl)
    }

    return _impl.popFront()
  }

  mutating func removeAll() {
    _impl = SinglyLinkedListImpl()
  }

  mutating func enumerateAndValidate(_ block: (Node.Element) -> Bool) {
    if !isKnownUniquelyReferenced(&_impl) {
      _impl = SinglyLinkedListImpl(proto: _impl)
    }

    _impl.enumerateAndValidate(block)
  }
}
