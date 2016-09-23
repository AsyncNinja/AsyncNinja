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

class Pipe<Periodic, Final> {
  private let _inputSema = DispatchSemaphore(value: 1)
  private let _outputSema = DispatchSemaphore(value: 0)
  private var _value: PipeValue<Periodic, Final>?
  
  init() {}
  
  @discardableResult
  func push(_ value: PipeValue<Periodic, Final>) -> Bool {
    _inputSema.wait()
    defer { _outputSema.signal() }
    
    if nil != _value {
      _inputSema.signal()
      return false
    } else {
      _value = value
      return true
    }
  }
  
  func pop() -> PipeValue<Periodic, Final> {
    _outputSema.wait()
    defer { _inputSema.signal() }
    let value = _value!
    switch value {
    case .periodic:
      _value = nil
    case .final:
      _outputSema.signal()
    }
    return value
  }
}

public enum PipeValue<Periodic, Final> {
  case periodic(Periodic)
  case final(Final)
}

public class PipeInput<Periodic, Final> {
  weak var pipe: Pipe<Periodic, Final>?
  
  init(pipe: Pipe<Periodic, Final>) {
    self.pipe = pipe
  }
  
  @discardableResult
  func push(_ value: PipeValue<Periodic, Final>) -> Bool {
    guard let pipe = self.pipe else { return false }
    return pipe.push(value)
  }

  @discardableResult
  public func push(periodic: Periodic) -> Bool {
    return self.push(.periodic(periodic))
  }
  
  @discardableResult
  public func push(final: Final) -> Bool {
    return self.push(.final(final))
  }
}

public extension PipeInput where Final : _Fallible {
  @discardableResult
  public func push(success: Final.Success) -> Bool {
    return self.push(final: Final(success: success))
  }

  @discardableResult
  public func push(failure: Error) -> Bool {
    return self.push(.final(Final(failure: failure)))
  }
}

public class PipeOutput<Periodic, Final> {
  let pipe: Pipe<Periodic, Final>
  
  init(pipe: Pipe<Periodic, Final>) {
    self.pipe = pipe
  }
  
  public func pop() -> PipeValue<Periodic, Final> {
    return self.pipe.pop()
  }
}

public typealias PipesPair<Periodic, Final> = (input: PipeInput<Periodic, Final>, output: PipeOutput<Periodic, Final>)

public func makePipesPair<Periodic, Final>() -> PipesPair<Periodic, Final> {
  let pipe = Pipe<Periodic, Final>()
  return (PipeInput<Periodic, Final>(pipe: pipe), PipeOutput<Periodic, Final>(pipe: pipe))
}
