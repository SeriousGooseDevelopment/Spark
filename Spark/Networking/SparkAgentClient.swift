import Foundation

// MARK: - Wire types

struct DeviceBedtime: Codable, Hashable {
    var enabled: Bool
    var start: String
    var wake: String
}

struct DeviceRules: Codable, Hashable {
    var enabled: Bool
    var contentFilter: String
    var dailyLimitMinutes: Int?
    var bedtime: DeviceBedtime?

    enum CodingKeys: String, CodingKey {
        case enabled
        case contentFilter = "content_filter"
        case dailyLimitMinutes = "daily_limit_minutes"
        case bedtime
    }
}

struct DeviceUsage: Codable, Hashable {
    var usedMinutesToday: Double
    var limitMinutes: Int?
    var cutoffActive: Bool

    enum CodingKeys: String, CodingKey {
        case usedMinutesToday = "used_minutes_today"
        case limitMinutes = "limit_minutes"
        case cutoffActive = "cutoff_active"
    }
}

struct ServiceCatalogEntry: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var groupId: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case groupId = "group_id"
    }
}

struct DeviceBlocklist: Codable, Hashable {
    var apps: [String]
    var sites: [String]
}

enum SparkAgentError: Error, LocalizedError {
    case notPaired
    case alreadyPaired
    case http(Int)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .notPaired: return "Not paired with a Spark box."
        case .alreadyPaired: return "This box is already paired to another device."
        case .http(let code): return "The Spark box returned an error (\(code))."
        case .network(let message): return message
        }
    }
}

// MARK: - Protocol

protocol SparkAgentClientProtocol: AnyObject {
    func configure(box: PairedBox?, token: String?)
    func pair(host: String, port: Int, clientName: String) async throws -> (token: String, boxName: String)
    func unpair() async
    func fetchStatus() async throws -> (protectionEnabled: Bool, dnsRunning: Bool)
    func setProtection(_ enabled: Bool) async throws
    func fetchStats() async throws -> (blocked: Int, queries: Int)
    func fetchDevices() async throws -> [AgentDevice]
    func claimDevice(mac: String, name: String) async throws
    func fetchRules(mac: String) async throws -> DeviceRules
    func setRules(mac: String, patch: [String: Any]) async throws
    func fetchUsage(mac: String) async throws -> DeviceUsage
    func deleteDevice(mac: String) async throws
    func fetchServiceCatalog() async throws -> [ServiceCatalogEntry]
    func fetchBlocklist(mac: String) async throws -> DeviceBlocklist
    func setBlocklist(mac: String, apps: [String]?, sites: [String]?) async throws
}

// MARK: - Live implementation

final class LiveSparkAgentClient: SparkAgentClientProtocol {
    private var pairedBox: PairedBox?
    private var token: String?

    func configure(box: PairedBox?, token: String?) {
        pairedBox = box
        self.token = token
    }

    private func request(
        _ path: String, method: String = "GET", body: [String: Any]? = nil,
        overrideHost: String? = nil, overridePort: Int? = nil, authorized: Bool = true
    ) async throws -> (Data, Int) {
        let host = overrideHost ?? pairedBox?.host ?? ""
        let port = overridePort ?? pairedBox?.port ?? 8787
        guard !host.isEmpty, let url = URL(string: "http://\(host):\(port)\(path)") else {
            throw SparkAgentError.network("No Spark box configured")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.timeoutInterval = 8
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if authorized, let token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                throw SparkAgentError.network("No response from Spark box")
            }
            return (data, http.statusCode)
        } catch let error as SparkAgentError {
            throw error
        } catch {
            throw SparkAgentError.network("Couldn't reach the Spark box on your network")
        }
    }

    func pair(host: String, port: Int, clientName: String) async throws -> (token: String, boxName: String) {
        let (data, status) = try await request(
            "/pair", method: "POST", body: ["client_name": clientName],
            overrideHost: host, overridePort: port, authorized: false
        )
        if status == 409 { throw SparkAgentError.alreadyPaired }
        guard status == 200 else { throw SparkAgentError.http(status) }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        guard let newToken = json["token"] as? String, let boxName = json["box_name"] as? String else {
            throw SparkAgentError.network("Malformed pairing response")
        }
        token = newToken
        pairedBox = PairedBox(boxName: boxName, host: host, port: port)
        return (newToken, boxName)
    }

    func unpair() async {
        _ = try? await request("/unpair", method: "POST")
        token = nil
        pairedBox = nil
    }

    func fetchStatus() async throws -> (protectionEnabled: Bool, dnsRunning: Bool) {
        let (data, status) = try await request("/status")
        guard status == 200 else { throw SparkAgentError.http(status) }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return (json["protection_enabled"] as? Bool ?? false, json["dns_running"] as? Bool ?? false)
    }

    func setProtection(_ enabled: Bool) async throws {
        let (_, status) = try await request("/protection", method: "POST", body: ["enabled": enabled])
        guard status == 200 else { throw SparkAgentError.http(status) }
    }

    func fetchStats() async throws -> (blocked: Int, queries: Int) {
        let (data, status) = try await request("/stats")
        guard status == 200 else { throw SparkAgentError.http(status) }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        return (json["num_blocked_filtering"] as? Int ?? 0, json["num_dns_queries"] as? Int ?? 0)
    }

    func fetchDevices() async throws -> [AgentDevice] {
        let (data, status) = try await request("/devices")
        guard status == 200 else { throw SparkAgentError.http(status) }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let list = json["devices"] as? [[String: Any]] ?? []
        return list.compactMap { d in
            guard let mac = d["mac"] as? String else { return nil }
            return AgentDevice(mac: mac, ip: d["ip"] as? String ?? "",
                                name: d["name"] as? String ?? "", online: d["online"] as? Bool ?? false,
                                source: d["source"] as? String ?? "arp_only")
        }
    }

    func claimDevice(mac: String, name: String) async throws {
        let (_, status) = try await request("/devices/\(mac)/claim", method: "POST", body: ["name": name])
        guard status == 200 else { throw SparkAgentError.http(status) }
    }

    func fetchRules(mac: String) async throws -> DeviceRules {
        let (data, status) = try await request("/devices/\(mac)/rules")
        guard status == 200 else { throw SparkAgentError.http(status) }
        return try JSONDecoder().decode(DeviceRules.self, from: data)
    }

    func setRules(mac: String, patch: [String: Any]) async throws {
        let (_, status) = try await request("/devices/\(mac)/rules", method: "PUT", body: patch)
        guard status == 200 else { throw SparkAgentError.http(status) }
    }

    func fetchUsage(mac: String) async throws -> DeviceUsage {
        let (data, status) = try await request("/devices/\(mac)/usage")
        guard status == 200 else { throw SparkAgentError.http(status) }
        return try JSONDecoder().decode(DeviceUsage.self, from: data)
    }

    func deleteDevice(mac: String) async throws {
        let (_, status) = try await request("/devices/\(mac)", method: "DELETE")
        guard status == 200 else { throw SparkAgentError.http(status) }
    }

    func fetchServiceCatalog() async throws -> [ServiceCatalogEntry] {
        let (data, status) = try await request("/services/catalog")
        guard status == 200 else { throw SparkAgentError.http(status) }
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let list = json["services"] as? [[String: Any]] ?? []
        return list.compactMap { d in
            guard let id = d["id"] as? String else { return nil }
            return ServiceCatalogEntry(id: id, name: d["name"] as? String ?? id, groupId: d["group_id"] as? String ?? "")
        }
    }

    func fetchBlocklist(mac: String) async throws -> DeviceBlocklist {
        let (data, status) = try await request("/devices/\(mac)/blocklist")
        guard status == 200 else { throw SparkAgentError.http(status) }
        return try JSONDecoder().decode(DeviceBlocklist.self, from: data)
    }

    func setBlocklist(mac: String, apps: [String]?, sites: [String]?) async throws {
        var patch: [String: Any] = [:]
        if let apps { patch["apps"] = apps }
        if let sites { patch["sites"] = sites }
        let (_, status) = try await request("/devices/\(mac)/blocklist", method: "PUT", body: patch)
        guard status == 200 else { throw SparkAgentError.http(status) }
    }
}

// MARK: - Mock implementation (default for tests/CI — fail-safe, never touches the network)

final class MockSparkAgentClient: SparkAgentClientProtocol {
    private var rulesByMac: [String: DeviceRules] = [:]
    private var usageByMac: [String: DeviceUsage] = [:]
    private var blocklistsByMac: [String: DeviceBlocklist] = [:]
    private let catalog: [ServiceCatalogEntry] = [
        ServiceCatalogEntry(id: "tiktok", name: "TikTok", groupId: "social_network"),
        ServiceCatalogEntry(id: "instagram", name: "Instagram", groupId: "social_network"),
        ServiceCatalogEntry(id: "facebook", name: "Facebook", groupId: "social_network"),
        ServiceCatalogEntry(id: "snapchat", name: "Snapchat", groupId: "social_network"),
        ServiceCatalogEntry(id: "x", name: "X (Twitter)", groupId: "social_network"),
        ServiceCatalogEntry(id: "youtube", name: "YouTube", groupId: "video"),
        ServiceCatalogEntry(id: "netflix", name: "Netflix", groupId: "video"),
        ServiceCatalogEntry(id: "twitch", name: "Twitch", groupId: "video"),
        ServiceCatalogEntry(id: "discord", name: "Discord", groupId: "messaging"),
        ServiceCatalogEntry(id: "whatsapp", name: "WhatsApp", groupId: "messaging"),
        ServiceCatalogEntry(id: "roblox", name: "Roblox", groupId: "games"),
        ServiceCatalogEntry(id: "reddit", name: "Reddit", groupId: "social_network"),
    ]

    func configure(box: PairedBox?, token: String?) {}

    private func delay() async {
        try? await Task.sleep(for: .milliseconds(150))
    }

    func pair(host: String, port: Int, clientName: String) async throws -> (token: String, boxName: String) {
        await delay()
        return ("mock-token", "Mock Spark Box")
    }

    func unpair() async { await delay() }

    func fetchStatus() async throws -> (protectionEnabled: Bool, dnsRunning: Bool) {
        await delay()
        return (true, true)
    }

    func setProtection(_ enabled: Bool) async throws { await delay() }

    func fetchStats() async throws -> (blocked: Int, queries: Int) {
        await delay()
        return (1284, 6320)
    }

    func fetchDevices() async throws -> [AgentDevice] {
        await delay()
        return [AgentDevice(mac: "aa:bb:cc:dd:ee:01", ip: "192.168.1.50", name: "", online: true)]
    }

    func claimDevice(mac: String, name: String) async throws {
        await delay()
        rulesByMac[mac] = DeviceRules(enabled: true, contentFilter: "off", dailyLimitMinutes: nil, bedtime: nil)
        usageByMac[mac] = DeviceUsage(usedMinutesToday: 0, limitMinutes: nil, cutoffActive: false)
    }

    func fetchRules(mac: String) async throws -> DeviceRules {
        await delay()
        return rulesByMac[mac] ?? DeviceRules(enabled: true, contentFilter: "off", dailyLimitMinutes: nil, bedtime: nil)
    }

    func setRules(mac: String, patch: [String: Any]) async throws {
        await delay()
        var rules = rulesByMac[mac] ?? DeviceRules(enabled: true, contentFilter: "off", dailyLimitMinutes: nil, bedtime: nil)
        if let enabled = patch["enabled"] as? Bool { rules.enabled = enabled }
        if let filter = patch["content_filter"] as? String { rules.contentFilter = filter }
        if patch.keys.contains("daily_limit_minutes") { rules.dailyLimitMinutes = patch["daily_limit_minutes"] as? Int }
        if patch.keys.contains("bedtime") {
            if let bt = patch["bedtime"] as? [String: Any],
               let enabled = bt["enabled"] as? Bool,
               let start = bt["start"] as? String,
               let wake = bt["wake"] as? String {
                rules.bedtime = DeviceBedtime(enabled: enabled, start: start, wake: wake)
            } else {
                rules.bedtime = nil
            }
        }
        rulesByMac[mac] = rules
    }

    func fetchUsage(mac: String) async throws -> DeviceUsage {
        await delay()
        return usageByMac[mac] ?? DeviceUsage(usedMinutesToday: 0, limitMinutes: nil, cutoffActive: false)
    }

    func deleteDevice(mac: String) async throws {
        await delay()
        rulesByMac.removeValue(forKey: mac)
        usageByMac.removeValue(forKey: mac)
        blocklistsByMac.removeValue(forKey: mac)
    }

    func fetchServiceCatalog() async throws -> [ServiceCatalogEntry] {
        await delay()
        return catalog
    }

    func fetchBlocklist(mac: String) async throws -> DeviceBlocklist {
        await delay()
        return blocklistsByMac[mac] ?? DeviceBlocklist(apps: [], sites: [])
    }

    func setBlocklist(mac: String, apps: [String]?, sites: [String]?) async throws {
        await delay()
        var bl = blocklistsByMac[mac] ?? DeviceBlocklist(apps: [], sites: [])
        if let apps { bl.apps = apps }
        if let sites { bl.sites = sites }
        blocklistsByMac[mac] = bl
    }
}
