import Foundation

/// Finds Spark Agent boxes on the local network via Bonjour. Uses
/// `NetServiceBrowser` + `NetService.resolve`, not `NWBrowser`: resolution
/// hands back ready-to-use `hostName`/`port` for building a URL directly,
/// where `NWBrowser` would need a second `NWConnection`-based resolve step
/// for the same result.
@MainActor
final class BonjourDiscovery: NSObject {
    static let serviceType = "_sparkagent._tcp."

    private let browser = NetServiceBrowser()
    private var resolving: [NetService] = []
    private var onFound: ((DiscoveredBox) -> Void)?

    func start(onFound: @escaping (DiscoveredBox) -> Void) {
        self.onFound = onFound
        browser.delegate = self
        browser.searchForServices(ofType: Self.serviceType, inDomain: "local.")
    }

    func stop() {
        browser.stop()
        resolving.forEach { $0.stop() }
        resolving.removeAll()
        onFound = nil
    }
}

extension BonjourDiscovery: NetServiceBrowserDelegate {
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        Task { @MainActor in
            service.delegate = self
            resolving.append(service)
            service.resolve(withTimeout: 5)
        }
    }
}

extension BonjourDiscovery: NetServiceDelegate {
    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        Task { @MainActor in
            guard var host = sender.hostName else { return }
            if host.hasSuffix(".") { host.removeLast() }
            let box = DiscoveredBox(name: sender.name, host: host, port: sender.port)
            onFound?(box)
            resolving.removeAll { $0 == sender }
        }
    }

    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        Task { @MainActor in
            resolving.removeAll { $0 == sender }
        }
    }
}
