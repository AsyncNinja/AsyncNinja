//
//  PropertyWrappers.swift
//  AsyncNinja
//
//  Created by Serhii Vynnychenko on 12/2/19.
//

import Foundation

/// using: @WrappedProducer var variable = "String Value"
/// variable can be used as usual
/// channel can be accessed as $variable
@propertyWrapper public struct WrappedProducer<Value> {
  public var wrappedValue : Value { didSet { _producer.update(wrappedValue)  } }
  
  /// The property that can be accessed with the `$` syntax and allows access to the `Channel`
  public var projectedValue: Channel<Value, Void> { get { return _producer } }
  
  private let _producer : Producer<Value, Void>
  
  /// Initialize the storage of the Published property as well as the corresponding `Publisher`.
  public init(wrappedValue: Value) {
    self.wrappedValue = wrappedValue
    self._producer = Producer<Value,Void>(bufferSize: 1, bufferedUpdates: [wrappedValue])
  }
}
