import NIO

public protocol NIODMXUniverseDelegate {
    func didReceivePacket(on universe: NIODMXUniverse, _ packet: SACNPacket)
}

public class NIODMXUniverse{

    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    let bootstrap: DatagramBootstrap
    let channel: Channel
    public let number: DMXUniverseNumber

    private var currentHandler: NIODMXUniverseDelegateHandler?

    public func setDelegate(_ delegate: NIODMXUniverseDelegate?) throws {

        if let current = self.currentHandler {
            _ = try self.channel.pipeline.remove(handler: current).wait()
        }

        guard let newDelegate = delegate else { return }

        let newHandler = NIODMXUniverseDelegateHandler(delegate: newDelegate)
        newHandler.universe = self

        try self.channel.pipeline.add(handler: newHandler).wait()
        self.currentHandler = newHandler
    }

    public init(universe: DMXUniverseNumber, on interface: ACNIOInterface? = nil, port: UInt16 = E131_DEFAULT_PORT) throws {

        self.number = universe

        self.bootstrap = DatagramBootstrap(group: self.group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEPORT), value: 1)

            .channelInitializer { channel in
                // always instantiate the handler _within_ the closure as
                // it may be called multiple times (for example if the hostname
                // resolves to both IPv4 and IPv6 addresses, cf. Happy Eyeballs).
                channel.pipeline.add(handler: NIODMXUniverseChannelHandler())
        }

        let multicastGroup = try SocketAddress(ipAddress: universe.ipAddress, port: port)
        debugPrint("Joining Multicast Group for \(universe.ipAddress):\(port)")
        self.channel = try bootstrap.bind(to: SocketAddress(ipAddress: "0.0.0.0", port: port))
            .then { channel -> EventLoopFuture<Channel> in
                let channel = channel as! MulticastChannel
                return channel.joinGroup(multicastGroup).map{ channel }
            }
            .then { channel -> EventLoopFuture<Channel> in
                guard let targetInterface = interface else {
                    return channel.eventLoop.newSucceededFuture(result: channel)
                }

                let provider = channel as! SocketOptionProvider

                switch targetInterface.interface.address {
                case .v4(let addr):
                    return provider.setIPMulticastIF(addr.address.sin_addr).map { channel }
                case .v6:
                    return provider.setIPv6MulticastIF(CUnsignedInt(targetInterface.interface.interfaceIndex)).map { channel }
                case .unixDomainSocket:
                    preconditionFailure("Should not be possible to create a multicast socket on a unix domain socket")
                }
            }
            .wait()

        debugPrint("=== BOUND!!!")
    }

    public func close() throws {
        try self.channel.close(mode: .all).wait()
    }

    public func waitUntilClosed() throws {
        try self.channel.closeFuture.wait()
    }
}

class NIODMXUniverseChannelHandler: ChannelInboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias InboundOut = SACNPacket

    private var counter: UInt8 = 255

    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {

        let unwrapped = self.unwrapInboundIn(data)

        guard let packet = SACNPacket(unwrapped.data) else {
            debugPrint("== skipping packet")
            return
        }

        ctx.fireChannelRead(self.wrapInboundOut(packet))
    }

    func errorCaught(ctx: ChannelHandlerContext, error: Error) {
        debugPrint(error, error.localizedDescription)
    }

    private func packetIsValid(_ packet: SACNPacket) -> Bool {

        if counter == UInt8.max {
            counter = 0
        }

        guard packet.sequenceNumber < counter else { return false }

        return true
    }
}

class NIODMXUniverseDelegateHandler: ChannelInboundHandler {
    typealias InboundIn = SACNPacket

    let delegate: NIODMXUniverseDelegate
    weak var universe: NIODMXUniverse?

    init(delegate: NIODMXUniverseDelegate){
        self.delegate = delegate
    }

    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {
        let unwrapped = self.unwrapInboundIn(data)
        guard let universe = self.universe else { return }
        self.delegate.didReceivePacket(on: universe, unwrapped)
    }
}
