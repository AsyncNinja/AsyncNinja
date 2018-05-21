//
//  Copyright (c) 2018 Anton Mironov
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

public extension EventSource {
  private static func _prepareReduceUpdates<Key: Hashable>(
    channelsByKey: [Key: Channel<Any, Void>]
    ) -> Channel<[Key: Any], Void> {
    let producer = Producer<[Key: Any], Void>(bufferSize: 1)

    var isComplete = false
    var unsetKeys = Set(channelsByKey.keys)
    var uncompletedKeys = unsetKeys
    var values = [Key: Any]()
    var locking = makeLocking(isFair: true)

    for (key, channel) in channelsByKey {
      let handler = channel.makeHandler(executor: .immediate) { (event, originalExecutor) in
        switch event {
        case let .update(update):
          let newValues: [Key: Any]?
          locking.lock()
          if isComplete {
            newValues = nil
          } else {
            unsetKeys.remove(key)
            values[key] = update
            newValues = unsetKeys.isEmpty ? values : nil
          }
          locking.unlock()
          if let newValues = newValues {
            producer.update(newValues, from: originalExecutor)
          }
        case .completion(.success):
          let shouldComplete: Bool
          locking.lock()
          if isComplete {
            shouldComplete = false
          } else {
            uncompletedKeys.remove(key)
            isComplete = uncompletedKeys.isEmpty
            shouldComplete = isComplete
          }
          locking.unlock()
          if shouldComplete {
            producer.succeed(from: originalExecutor)
          }
        case let .completion(.failure(error)):
          let shouldComplete: Bool
          locking.lock()
          shouldComplete = !isComplete
          isComplete = true
          locking.unlock()
          if shouldComplete {
            producer.fail(error, from: originalExecutor)
          }
        }
      }

      producer._asyncNinja_retainHandlerUntilFinalization(handler)
    }

    return producer
  }

  static func reduceUpdates<Key: Hashable>(
    channelsByKey: [Key: Channel<Any, Void>],
    executor: Executor = .primary,
    pure: Bool = true,
    cancellationToken: CancellationToken? = nil,
    combiner: @escaping ([Key: Any]) throws -> Update) -> Channel<Update, Void> {
    return _prepareReduceUpdates(channelsByKey: channelsByKey)
      .map(executor: executor, pure: pure, cancellationToken: cancellationToken, bufferSize: .inherited, combiner)
  }

  static func reduceUpdates<Key: Hashable, C: ExecutionContext, Update>(
    channelsByKey: [Key: Channel<Any, Void>],
    context: C,
    executor: Executor? = nil,
    pure: Bool = true,
    cancellationToken: CancellationToken? = nil,
    combiner: @escaping (C, [Key: Any]) throws -> Update) -> Channel<Update, Void> {
    return _prepareReduceUpdates(channelsByKey: channelsByKey)
      .map(context: context, executor: executor, pure: pure,
           cancellationToken: cancellationToken, bufferSize: .inherited, combiner)
  }
}

public extension ExecutionContext {
  func makeDerivedProperty<T, S: Sequence>(
    for keyPaths: S,
    combiner: @escaping (DerivedPropertyValuesProvider<Self>) throws -> T
    ) -> Channel<T, Void> where S.Element == PartialKeyPath<Self> {
    var channelsByKey = [PartialKeyPath<Self>: Channel<Any, Void>]()
    for keyPath in keyPaths {
      let channel: Channel<Any, Void> = _updating(forKeyPath: keyPath, from: .some(.immediate))
      channelsByKey[keyPath] = channel
    }

    return Channel<T, Void>.reduceUpdates(channelsByKey: channelsByKey,
                                          context: self,
                                          executor: .immediate
    ) { (_, valuesByKeyPath) -> T in
      return try combiner(DerivedPropertyValuesProvider<Self>(valuesByKey: valuesByKeyPath))
    }
  }
}

public struct DerivedPropertyValuesProvider<C: ExecutionContext> {
  private let _valuesByKey: [PartialKeyPath<C>: Any]

  init(valuesByKey: [PartialKeyPath<C>: Any]) {
    _valuesByKey = valuesByKey
  }

  func provide<T>(forKeyPath keyPath: KeyPath<C, T>) -> T {
    return _valuesByKey[keyPath] as! T
  }

  subscript <T>(_ keyPath: KeyPath<C, T>) -> T {
    return _valuesByKey[keyPath] as! T
  }
}
