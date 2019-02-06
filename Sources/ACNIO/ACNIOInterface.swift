//
//  ACNIOInterface.swift
//  ACNIO
//
//  Created by Jeremy Massel on 2019-01-12.
//

import Foundation
import NIO

public enum ACNIOInterfaceType{
    case IPv4
    case IPv6
}

public struct ACNIOInterface {

    internal let interface: NIONetworkInterface

    public static var all: [NIONetworkInterface] {
        do{
            return try System.enumerateInterfaces()
        }
        catch let err{
            debugPrint(err.localizedDescription)
            return []
        }
    }

    public static var ipv4: [NIONetworkInterface] {
        return all.filter{ $0.address.isIPv4 }
    }

    public static var ipv6: [NIONetworkInterface] {
        return all.filter{ $0.address.isIPv6 }
    }

    public init(interfaceHandle: String, addressType: ACNIOInterfaceType = .IPv4) throws {

        let _interface = try System.enumerateInterfaces().first{
            $0.name == interfaceHandle && $0.address.matches(addressType)

        }

        guard let interface = _interface else {
            throw InterfaceNotFoundError()
        }

        self.interface = interface
    }

    init(ipAddress: String) throws {
        let _interface = try System.enumerateInterfaces().first{ $0.address.description == ipAddress }

        guard let interface = _interface else {
            throw InterfaceNotFoundError()
        }

        self.interface = interface
    }

    struct InterfaceNotFoundError : Error { }
}

private extension SocketAddress {

    var isIPv4: Bool {
        switch self{
            case .v4(_): return true
            default: return false
        }
    }

    var isIPv6: Bool {
        switch self{
            case .v6(_): return true
            default: return false
        }
    }

    func matches(_ interface: ACNIOInterfaceType) -> Bool {
        switch interface {
            case .IPv4: return self.isIPv4
            case .IPv6: return self.isIPv6
        }
    }
}
