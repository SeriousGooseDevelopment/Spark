import Foundation

/// The box Spark is paired with. Persisted (host/name via UserDefaults, the
/// bearer token via Keychain) — the one deliberate exception to "no Codable
/// persistence" in this app, since pairing identity must survive relaunch.
struct PairedBox: Codable, Hashable {
    var boxName: String
    var host: String
    var port: Int
}

/// A box seen on the network during pairing discovery, not yet paired.
struct DiscoveredBox: Identifiable, Hashable {
    var id: String { host }
    let name: String
    let host: String
    let port: Int
}
