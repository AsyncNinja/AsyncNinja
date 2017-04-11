//
//  Copyright (c) 2017 Anton Mironov
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

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  import Foundation
  import SystemConfiguration

  class NetworkReachabilityManager {
    typealias ProducerBox = WeakBox<Producer<SCNetworkReachabilityFlags, Void>>

    static let `default` = NetworkReachabilityManager()
    let internalQueue = DispatchQueue(label: "NetworkReachabilityManager")
    var locking = makeLocking()
    var producerBoxesByHostName = [String: ProducerBox]()
    var producerBoxesByAddress = [sockaddrWrapper: ProducerBox]()
    var producerBoxesByAddressPair = [AddressPair: ProducerBox]()

    init() {
    }

    func channel(addressPair: AddressPair) -> Channel<SCNetworkReachabilityFlags, Void> {
      func fetch() -> (mustSetup: Bool, producer: Producer<SCNetworkReachabilityFlags, Void>) {
        if let producer = producerBoxesByAddressPair[addressPair]?.value {
          return (false, producer)
        } else {
          let producer = Producer<SCNetworkReachabilityFlags, Void>()
          producerBoxesByAddressPair[addressPair] = WeakBox(producer)
          return (true, producer)
        }
      }

      func makeNetworkReachability() -> SCNetworkReachability? {
        let localAddress: UnsafePointer<sockaddr>? = addressPair.localAddress?.data.withUnsafeBytes { $0 }
        let remoteAddress: UnsafePointer<sockaddr>? = addressPair.remoteAddress?.data.withUnsafeBytes { $0 }
        return SCNetworkReachabilityCreateWithAddressPair(nil, localAddress, remoteAddress)
      }

      return channel(fetch: fetch, makeNetworkReachability: makeNetworkReachability)
    }

    func channelForInternetConnection() -> Channel<SCNetworkReachabilityFlags, Void> {
      var address = sockaddr_in()
      address.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
      address.sin_family = sa_family_t(AF_INET)
      address.sin_port = 0
      return channel(address: sockaddrWrapper(sockaddr_in: &address))
    }

    func channel(address: sockaddrWrapper) -> Channel<SCNetworkReachabilityFlags, Void> {
      func fetch() -> (mustSetup: Bool, producer: Producer<SCNetworkReachabilityFlags, Void>) {
        if let producer = producerBoxesByAddress[address]?.value {
          return (false, producer)
        } else {
          let producer = Producer<SCNetworkReachabilityFlags, Void>()
          producerBoxesByAddress[address] = WeakBox(producer)
          return (true, producer)
        }
      }

      func makeNetworkReachability() -> SCNetworkReachability? {
        return address.data.withUnsafeBytes {
          return SCNetworkReachabilityCreateWithAddress(nil, $0)
        }
      }

      return channel(fetch: fetch, makeNetworkReachability: makeNetworkReachability)
    }

    func channel(hostName: String) -> Channel<SCNetworkReachabilityFlags, Void> {
      func fetch() -> (mustSetup: Bool, producer: Producer<SCNetworkReachabilityFlags, Void>) {
        if let producer = producerBoxesByHostName[hostName]?.value {
          return (false, producer)
        } else {
          let producer = Producer<SCNetworkReachabilityFlags, Void>()
          producerBoxesByHostName[hostName] = WeakBox(producer)
          return (true, producer)
        }
      }

      func makeNetworkReachability() -> SCNetworkReachability? {
        return hostName.withCString { SCNetworkReachabilityCreateWithName(nil, $0) }
      }

      return channel(fetch: fetch, makeNetworkReachability: makeNetworkReachability)
    }

    private func channel(
      fetch: () -> (mustSetup: Bool, producer: Producer<SCNetworkReachabilityFlags, Void>),
      makeNetworkReachability: () -> SCNetworkReachability?
      ) -> Channel<SCNetworkReachabilityFlags, Void>
    {
      let (mustSetup, producer): (Bool, Producer<SCNetworkReachabilityFlags, Void>) = locking.locker(fetch)

      if mustSetup {
        if let networkReachability = makeNetworkReachability() {
          setup(producer: producer, networkReachability: networkReachability)
        } else {
          producer.fail(AsyncNinjaError.networkReachabilityDetectionFailed)
        }
      }

      return producer
    }

    private func setup(
      producer: Producer<SCNetworkReachabilityFlags, Void>,
      networkReachability: SCNetworkReachability)
    {
      let queue = internalQueue
      queue.async {
        var flags = SCNetworkReachabilityFlags()
        guard SCNetworkReachabilityGetFlags(networkReachability, &flags)
          else {
            producer.fail(AsyncNinjaError.networkReachabilityDetectionFailed)
            return
        }

        producer.update(flags)
        let unmanagedProducerBox = Unmanaged.passRetained(WeakBox(producer))
        var context = SCNetworkReachabilityContext(
          version: 0,
          info: unmanagedProducerBox.toOpaque(),
          retain: { return UnsafeRawPointer(Unmanaged<ProducerBox>.fromOpaque($0).retain().toOpaque()) },
          release: { Unmanaged<ProducerBox>.fromOpaque($0).release() },
          copyDescription: nil)
        if SCNetworkReachabilitySetCallback(networkReachability, { (_, flags, info) in
          let unmanagedProducerBox = Unmanaged<ProducerBox>.fromOpaque(info!)
          unmanagedProducerBox.retain().takeUnretainedValue().value?.update(flags)
          unmanagedProducerBox.release()
        }, &context),
          SCNetworkReachabilitySetDispatchQueue(networkReachability, queue)
        {
          producer._asyncNinja_notifyFinalization {
            SCNetworkReachabilitySetCallback(networkReachability, nil, nil)
          }
        } else {
          producer.fail(AsyncNinjaError.networkReachabilityDetectionFailed)
        }

        unmanagedProducerBox.release()
      }
    }
  }

  public struct sockaddrWrapper: Hashable {
    let data: Data
    public var hashValue: Int { return data.hashValue }

    public init(sockaddr: UnsafePointer<sockaddr>) {
      self.data = Data(bytes: sockaddr, count: Int(sockaddr.pointee.sa_len))
    }

    public init(sockaddr_in: UnsafePointer<sockaddr_in>) {
      self = sockaddr_in.withMemoryRebound(to: sockaddr.self, capacity: 1, sockaddrWrapper.init(sockaddr:))
    }

    public static func ==(lhs: sockaddrWrapper, rhs: sockaddrWrapper) -> Bool {
      return lhs.data == rhs.data
    }
  }

  public extension sockaddrWrapper {
    var sockaddrRef: UnsafePointer<sockaddr> {
      return data.withUnsafeBytes {
        (bytes: UnsafePointer<sockaddr>) -> UnsafePointer<sockaddr> in
        return bytes
      }
    }
  }

  public struct AddressPair: Hashable {
    public var localAddress: sockaddrWrapper?
    public var remoteAddress: sockaddrWrapper?
    public var hashValue: Int { return (localAddress?.hashValue ?? 0) ^ (remoteAddress?.hashValue ?? 0) }

    public static func ==(lhs: AddressPair, rhs: AddressPair) -> Bool {
      return lhs.localAddress == rhs.localAddress && lhs.remoteAddress == rhs.remoteAddress
    }
  }

  extension SCNetworkReachabilityFlags: CustomStringConvertible {
    public var description: String {
      var spec = [(SCNetworkReachabilityFlags, String)]()
      #if os(iOS)
        spec.append((.isWWAN, "W"))
      #endif
      spec += [
        (.reachable, "R"),
        (.transientConnection, "t"),
        (.connectionRequired, "c"),
        (.connectionOnTraffic, "C"),
        (.interventionRequired, "i"),
        (.connectionOnDemand, "D"),
        (.isLocalAddress, "l"),
        (.isDirect, "d"),
      ]

      return spec
        .map { (flag, description) -> String in contains(flag) ? description : "-" }
        .joined()
    }

    public var isUnconditionallyReachableViaWifi: Bool {
      return contains(.reachable) && !contains(.connectionRequired)
    }

    public var isConditionallyReachableViaWifi: Bool {
      return !contains(.reachable)
      && contains(.connectionRequired)
      && (contains(.connectionOnTraffic) || contains(.connectionOnDemand))
      && !contains(.interventionRequired)
    }
    #if os(iOS)
    public var isReachableViaWWAN: Bool {
      return contains(.isWWAN)
    }
    #endif
  }

  // MARK: - public functions

  public func channel(addressPair: AddressPair) -> Channel<SCNetworkReachabilityFlags, Void> {
    return NetworkReachabilityManager.default.channel(addressPair: addressPair)
  }

  public func networkReachabilityForInternetConnection() -> Channel<SCNetworkReachabilityFlags, Void> {
    return NetworkReachabilityManager.default.channelForInternetConnection()
  }

  public func networkReachability(address: sockaddrWrapper) -> Channel<SCNetworkReachabilityFlags, Void> {
    return NetworkReachabilityManager.default.channel(address: address)
  }

  public func networkReachability(hostName: String) -> Channel<SCNetworkReachabilityFlags, Void> {
    return NetworkReachabilityManager.default.channel(hostName: hostName)
  }

#endif
