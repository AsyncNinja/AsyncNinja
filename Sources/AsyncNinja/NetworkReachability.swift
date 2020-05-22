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

#if os(macOS) || os(iOS) || os(tvOS)
  import Foundation
  import SystemConfiguration

  /// **internal use only**
  class NetworkReachabilityManager {
    typealias ProducerBox = WeakBox<Producer<SCNetworkReachabilityFlags, Void>>

    static let `default` = NetworkReachabilityManager()
    let internalQueue = DispatchQueue(label: "NetworkReachabilityManager", target: .global())
    var locking = makeLocking()
    var producerBoxesByHostName = [String: ProducerBox]()
    var producerBoxesByAddress = [NetworkAddress: ProducerBox]()
    var producerBoxesByAddressPair = [NetworkAddressPair: ProducerBox]()

    init() { }

    func channel(addressPair: NetworkAddressPair) -> Channel<SCNetworkReachabilityFlags, Void> {
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
        return addressPair.localAddress?.data.withUnsafeBytes { (localAddress: UnsafeRawBufferPointer) -> SCNetworkReachability? in
          addressPair.remoteAddress?.data.withUnsafeBytes { (remoteAddress: UnsafeRawBufferPointer) -> SCNetworkReachability? in
            return SCNetworkReachabilityCreateWithAddressPair(
              nil,
              localAddress.bindMemory(to: sockaddr.self).baseAddress,
              remoteAddress.bindMemory(to: sockaddr.self).baseAddress
            )
          }
        }
      }

      return channel(fetch: fetch, makeNetworkReachability: makeNetworkReachability)
    }

    func channelForInternetConnection() -> Channel<SCNetworkReachabilityFlags, Void> {
      var address = sockaddr_in()
      address.sin_len = __uint8_t(MemoryLayout<sockaddr_in>.size)
      address.sin_family = sa_family_t(AF_INET)
      address.sin_port = 0
      return channel(address: NetworkAddress(sockaddr_in: &address))
    }

    func channel(address: NetworkAddress) -> Channel<SCNetworkReachabilityFlags, Void> {
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
          ($0.bindMemory(to: sockaddr.self).baseAddress)
            .flatMap { SCNetworkReachabilityCreateWithAddress(nil, $0) }
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
      ) -> Channel<SCNetworkReachabilityFlags, Void> {
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
      networkReachability: SCNetworkReachability) {
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
          SCNetworkReachabilitySetDispatchQueue(networkReachability, queue) {
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

  // MARK: -

  /// Wraps sockaddr and it's derivetives into a convenient swift structure
  public struct NetworkAddress: Hashable {
    var data: Data

    /// Reference to a stored sockaddr
    public var sockaddrRef: UnsafePointer<sockaddr>? {
      return data.withUnsafeBytes {
        $0.bindMemory(to: sockaddr.self).baseAddress
      }
    }

    /// Initializes NetworkAddress with any sockaddr
    ///
    /// - Parameter sockaddr: to initialize NetworkAddress with
    public init(sockaddr: UnsafePointer<sockaddr>) {
      self.data = Data(bytes: sockaddr, count: Int(sockaddr.pointee.sa_len))
    }

    /// Initializes NetworkAddress with any sockaddr_in
    ///
    /// - Parameter sockaddr_in: to initialize NetworkAddress with
    public init(sockaddr_in: UnsafePointer<sockaddr_in>) {
      self = sockaddr_in.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        NetworkAddress.init(sockaddr: $0)
      }
    }

    /// is equal operator
    public static func == (lhs: NetworkAddress, rhs: NetworkAddress) -> Bool {
      return lhs.data == rhs.data
    }
  }

  // MARK: -

  /// **internal use only**
  struct NetworkAddressPair: Hashable {
    var localAddress: NetworkAddress?
    var remoteAddress: NetworkAddress?

    static func == (lhs: NetworkAddressPair, rhs: NetworkAddressPair) -> Bool {
      return lhs.localAddress == rhs.localAddress && lhs.remoteAddress == rhs.remoteAddress
    }
  }

  // MARK: -

  extension SCNetworkReachabilityFlags: CustomStringConvertible {

    /// Commonly known description of the flags written on Swift
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
        (.isDirect, "d")
      ]

      return spec
        .map {
            let (flag, description) = $0
            return contains(flag) ? description : "-"
        }
        .joined()
    }

    /// Returns true if network is reachable unconditionally
    public var isReachable: Bool {
      return contains(.reachable) && !contains(.connectionRequired)
    }

    /// Returns true if network is not reachable but it is possible to esteblish connection
    public var isConditionallyReachable: Bool {
      return !contains(.reachable)
      && contains(.connectionRequired)
      && (contains(.connectionOnTraffic) || contains(.connectionOnDemand))
      && !contains(.interventionRequired)
    }

    #if os(iOS)
    /// Returns true if network is reachable via WWAN
    public var isReachableViaWWAN: Bool {
      return contains(.isWWAN)
    }
    #endif
  }

  // MARK: - public functions

  /// Makes or returns cached channel that reports of reachability changes
  ///
  /// - Parameters:
  ///   - localAddress: local address associated with a network connection.
  ///     If nil, only the remote address is of interest
  ///   - remoteAddress: remote address associated with a network connection.
  ///     If nil, only the local address is of interest
  /// - Returns: channel that reports of reachability changes
  public func networkReachability(
    localAddress: NetworkAddress?,
    remoteAddress: NetworkAddress?
    ) -> Channel<SCNetworkReachabilityFlags, Void>
  {
    let addressPair = NetworkAddressPair(localAddress: localAddress, remoteAddress: remoteAddress)
    return NetworkReachabilityManager.default.channel(addressPair: addressPair)
  }

  /// Makes or returns cached channel that reports of reachability changes
  /// The channel will report of a internet connection availibility.
  ///
  /// - Returns: channel that reports of reachability changes
  public func networkReachabilityForInternetConnection() -> Channel<SCNetworkReachabilityFlags, Void> {
    return NetworkReachabilityManager.default.channelForInternetConnection()
  }

  /// Makes or returns cached channel that reports of reachability changes
  ///
  /// - Parameters:
  ///   - address: associated with a network connection.
  /// - Returns: channel that reports of reachability changes
  public func networkReachability(address: NetworkAddress) -> Channel<SCNetworkReachabilityFlags, Void> {
    return NetworkReachabilityManager.default.channel(address: address)
  }

  /// Makes or returns cached channel that reports of reachability changes
  ///
  /// - Parameter hostName: associated with a network connection.
  /// - Returns: channel that reports of reachability changes
  public func networkReachability(hostName: String) -> Channel<SCNetworkReachabilityFlags, Void> {
    return NetworkReachabilityManager.default.channel(hostName: hostName)
  }

#endif
