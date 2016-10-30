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

public class Pipe<Periodic, Final> : _PipeInput {
  private let _inputSema = DispatchSemaphore(value: 1)
  private let _outputSema = DispatchSemaphore(value: 0)
  private var _periodic: Periodic?
  private var _final: Final?
  
  public init() {}
  
  @discardableResult
  public func push(_ value: PipeValue<Periodic, Final>) -> Bool {
    _inputSema.wait()
    defer { _outputSema.signal() }

    if nil != _final {
      switch value {
      case .periodic(let periodic):
        _periodic = periodic
        return true
      case .final:
        _inputSema.signal()
        return false
      }
    } else {
      switch value {
      case .periodic(let periodic):
        _periodic = periodic
      case .final(let final):
        _final = final
      }
      return true
    }
  }

  @discardableResult
  public func pop() -> PipeValue<Periodic, Final> {
    _outputSema.wait()
    defer { _inputSema.signal() }

    if let periodic = _periodic {
      _periodic = nil
      return .periodic(periodic)
    } else if let final = _final {
      _outputSema.signal()
      return .final(final)
    } else {
      fatalError()
    }
  }
}

public enum PipeValue<Periodic, Final> {
  case periodic(Periodic)
  case final(Final)
}

public class PipeInput<Periodic, Final> : _PipeInput {
  weak var pipe: Pipe<Periodic, Final>?
  
  public init(pipe: Pipe<Periodic, Final>) {
    self.pipe = pipe
  }
  
  @discardableResult
  public func push(_ value: PipeValue<Periodic, Final>) -> Bool {
    guard let pipe = self.pipe else { return false }
    return pipe.push(value)
  }
}

public protocol _PipeInput {
  associatedtype Periodic
  associatedtype Final
  func push(_ value: PipeValue<Periodic, Final>) -> Bool
}

public extension _PipeInput {
  @discardableResult
  public func push(periodic: Periodic) -> Bool {
    return self.push(.periodic(periodic))
  }
  
  @discardableResult
  public func push(final: Final) -> Bool {
    return self.push(.final(final))
  }
}

public extension _PipeInput where Final : _Fallible {
  @discardableResult
  public func push(success: Final.Success) -> Bool {
    return self.push(final: Final(success: success))
  }
  
  @discardableResult
  public func push(failure: Swift.Error) -> Bool {
    return self.push(.final(Final(failure: failure)))
  }
}
