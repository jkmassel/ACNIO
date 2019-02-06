import ACNIO
import NIO

struct UniverseDelegate: NIODMXUniverseDelegate{
    func didReceivePacket(_ packet: SACNPacket) {
        debugPrint(packet.sourceName, packet.channels[0])
    }
}

let delegate = UniverseDelegate()

var unv = try! NIODMXUniverse(universe: 32)
try! unv.setDelegate(delegate)

try! unv.waitUntilClosed()
