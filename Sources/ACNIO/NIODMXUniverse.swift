import NIO

public protocol NIODMXUniverseDelegate {
    func didReceivePacket(on universe: NIODMXUniverse, _ packet: SACNPacket)
}

public typealias PortNumber = UInt16

public class NIODMXUniverse{

    let group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
    let bootstrap: DatagramBootstrap
    private var channel: Channel!

    public let number: DMXUniverseNumber
    public let port: PortNumber
    public let interface: ACNIOInterface?

    private var currentHandler: NIODMXUniverseDelegateHandler?
    private var currentDelegate: NIODMXUniverseDelegate?

    public func setDelegate(_ delegate: NIODMXUniverseDelegate?, on eventLoop: EventLoop) -> EventLoopFuture<Void> {

        let emptyPromise = eventLoop.newSucceededFuture(result: Void())

        return self.removeCurrentDelegate(on: eventLoop)
            .then{

                guard let newDelegate = delegate else {
                    return emptyPromise
                }

                let newHandler = NIODMXUniverseDelegateHandler(delegate: newDelegate)
                newHandler.universe = self

                return self.channel!.pipeline.add(handler: newHandler)
            }
    }

    private func removeCurrentDelegate(on eventLoop: EventLoop) -> EventLoopFuture<Void> {

        self.currentHandler = nil

        let emptyPromise = eventLoop.newSucceededFuture(result: Void())

        guard let channel = self.channel else {
            return emptyPromise
        }

        if let current = self.currentHandler {
            return channel.pipeline.remove(handler: current)
                .then{ _ in return emptyPromise }
        }

        return emptyPromise
    }

    private init(universe: DMXUniverseNumber, on interface: ACNIOInterface? = nil, port: PortNumber = E131_DEFAULT_PORT) {

        self.number = universe
        self.interface = interface
        self.port = port

        self.bootstrap = DatagramBootstrap(group: self.group)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .channelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEPORT), value: 1)

            .channelInitializer { channel in
                // always instantiate the handler _within_ the closure as
                // it may be called multiple times (for example if the hostname
                // resolves to both IPv4 and IPv6 addresses, cf. Happy Eyeballs).
                channel.pipeline.add(handler: NIODMXUniverseChannelHandler())
        }
    }

    public static func connect(to universe: DMXUniverseNumber, withEventLoop eventLoop: EventLoop, on interface: ACNIOInterface? = nil, port: PortNumber = E131_DEFAULT_PORT) -> EventLoopFuture<NIODMXUniverse> {

        let universe = NIODMXUniverse(universe: universe, on: interface, port: port)

        return universe.connect(on: eventLoop)
            .then { channel -> EventLoopFuture<NIODMXUniverse> in
                return eventLoop.newSucceededFuture(result: universe)
            }
    }

    fileprivate func connect(on eventLoop: EventLoop) -> EventLoopFuture<Channel> {

        do {
            let multicastGroup = try SocketAddress(ipAddress: self.number.ipAddress, port: port)

            return try bootstrap.bind(to: SocketAddress(ipAddress: "0.0.0.0", port: port))
                .hopTo(eventLoop: eventLoop)
                .then { channel -> EventLoopFuture<Channel> in
                    let channel = channel as! MulticastChannel
                    return channel.joinGroup(multicastGroup).map{ channel }
                }
                .then { channel -> EventLoopFuture<Channel> in
                    guard let targetInterface = self.interface else {
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
                .then{
                    self.channel = $0
                    return $0.eventLoop.newSucceededFuture(result: $0)
            }
        }
        catch let err {
            return eventLoop.newFailedFuture(error: err)
        }
    }

    public func close() -> EventLoopFuture<Void>{
        return self.channel.close(mode: .all)
    }

    public func waitUntilClosed() throws {
        try self.channel?.closeFuture.wait()
    }

    public var channelData = DMXChannels.empty

    deinit {
        try? self.waitUntilClosed()
    }
}

class NIODMXUniverseChannelHandler: ChannelInboundHandler {
    typealias InboundIn = AddressedEnvelope<ByteBuffer>
    typealias InboundOut = SACNPacket

    private var counter: UInt8 = 255

    func channelRead(ctx: ChannelHandlerContext, data: NIOAny) {

        debugPrint("Received Packet")

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
        universe.channelData = unwrapped.channels
        self.delegate.didReceivePacket(on: universe, unwrapped)
    }
}
