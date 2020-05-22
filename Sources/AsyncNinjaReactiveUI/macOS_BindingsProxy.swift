//
//  Copyright (c) 2019 Anton Mironov
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

#if os(macOS)

import AppKit
import AsyncNinja

class BindingProxy: NSObject, ObservationSessionItem {
  weak var producerProxy: ProducerProxy<Any?, Void>?
  @objc dynamic var value: Any? {
    didSet { processUpdate(value) }
  }
  unowned let object: NSObject
  let bindingName: NSBindingName
  let options: [NSBindingOption: Any]
  let executor: Executor

  var isEnabled: Bool = false {
    didSet {
      if oldValue == isEnabled {
        return
      } else if isEnabled {
        object.bind(bindingName, to: self, withKeyPath: "value", options: options)
      } else {
        object.unbind(bindingName)
      }
    }
  }

  static func makeProducerProxy(object: NSObject,
                                bindingName: NSBindingName,
                                options: [NSBindingOption: Any] = [
    .continuouslyUpdatesValue: true,
    .raisesForNotApplicableKeys: true
    ],
                                executor: Executor = .main,
                                initialValue: Any?) -> ProducerProxy<Any?, Void> {
    let observedObject = object.infoForBinding(bindingName)?[.observedObject]
    switch observedObject {
    case .none:
      return _makeProducerProxy(object: object,
                                bindingName: bindingName,
                                options: options,
                                executor: executor,
                                initialValue: initialValue)
    case .some(let existingProxy as BindingProxy):
      if let producerProxy = existingProxy.producerProxy {
        existingProxy.value = initialValue
        return producerProxy
      } else {
        existingProxy.isEnabled = false
        return _makeProducerProxy(object: object,
                                  bindingName: bindingName,
                                  options: options,
                                  executor: executor,
                                  initialValue: initialValue)
      }
    case .some(let existingObservedObject):
      fatalError("\(object) `\(bindingName)` is already bound to \(existingObservedObject). Cannod bind object twice")
    }
  }

  static func _makeProducerProxy(object: NSObject,
                                 bindingName: NSBindingName,
                                 options: [NSBindingOption: Any],
                                 executor: Executor,
                                 initialValue: Any?) -> ProducerProxy<Any?, Void> {
    let proxy = BindingProxy(object: object,
                             bindingName: .value,
                             executor: executor,
                             initialValue: initialValue)
    let producerProxy = ProducerProxy<Any?, Void>(
      updateExecutor: executor
    ) { (_, event, _) in
      if case let .update(value) = event {
        proxy.value = value
      }
    }
    proxy.producerProxy = producerProxy
    proxy.isEnabled = true
    proxy.processUpdate(proxy.value)

    return producerProxy
  }

  init(object: NSObject,
       bindingName: NSBindingName,
       options: [NSBindingOption: Any] = [
    .continuouslyUpdatesValue: true,
    .raisesForNotApplicableKeys: true
    ],
       executor: Executor,
       initialValue: Any?) {
    self.object = object
    self.bindingName = bindingName
    self.options = options
    self.executor = executor
    self.value = initialValue
  }

  func processUpdate(_ newValue: Any?) {
    _ = producerProxy?.tryUpdateWithoutHandling(newValue, from: executor)
  }

  deinit {
    isEnabled = false
  }
}

public extension Retainer where Self: NSObject {
  func updatable(
    forBindingName bindingName: NSBindingName,
    executor: Executor,
    from originalExecutor: Executor? = nil,
    observationSession: ObservationSession? = nil,
    initialValue: Any?) -> ProducerProxy<Any?, Void> {
    return BindingProxy.makeProducerProxy(object: self,
                                          bindingName: bindingName,
                                          initialValue: initialValue)
  }
}

#endif
