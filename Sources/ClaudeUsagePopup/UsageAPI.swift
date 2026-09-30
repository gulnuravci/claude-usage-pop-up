import Foundation

struct Meter: Codable, Equatable, Identifiable {
    var id: String
    var label: String
    var percent: Double
    var resetsAt: Date?
}

struct UsageSnapshot: Codable, Equatable {
    var session: Meter?
    var weekly: Meter?
    /// Per-model weekly limits (e.g. "Opus · week"), when your plan has them.
    var extras: [Meter] = []

    /// The fullest meter that actually blocks you (session or weekly).
    var worst: Meter? {
        [session, weekly].compactMap { $0 }.max { $0.percent < $1.percent }
    }
}

enum UsageError: LocalizedError, Equatable {
    case noCredentials
    case loginExpired
    case rateLimited(retryAfter: TimeInterval?)
    case http(Int)
    case network(String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .noCredentials:
            return "No Claude Code login found. Run `claude` in a terminal and log in once."
        case .loginExpired:
            return "Your Claude Code login expired. Open Claude Code (or Conductor) and send a message to refresh it."
        case .rateLimited:
            return "Anthropic asked us to slow down. Trying again in a few minutes."
        case .http(let code):
            return "Anthropic returned HTTP \(code). Trying again soon."
        case .network(let message):
            return "Can't reach Anthropic: \(message)"
        case .badResponse:
            return "Got a response we didn't understand. The usage API may have changed."
        }
    }
}

// MARK: - Credentials

/// Reads the OAuth token Claude Code saved when you logged in. Nothing is written or refreshed here;
/// Claude Code keeps the token fresh while you use it.
enum Credentials {
    struct Token {
        let accessToken: String
        let expiresAt: Date?
    }

    static func load() throws -> Token {
        if let env = ProcessInfo.processInfo.environment["CLAUDE_USAGE_TOKEN"], !env.isEmpty {
            return Token(accessToken: env, expiresAt: nil)
        }
        for source in [readKeychain, readCredentialsFile] {
            if let data = source(), let token = parse(data) { return token }
        }
        throw UsageError.noCredentials
    }

    /// Shelling out to `security` (instead of SecItem APIs) avoids a Keychain password prompt,
    /// since Claude Code itself uses `security` to manage this item.
    private static func readKeychain() -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", Config.keychainService, "-w"]
        let out = Pipe()
        process.standardOutput = out
        process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return data
    }

    private static func readCredentialsFile() -> Data? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return try? Data(contentsOf: home.appendingPathComponent(".claude/.credentials.json"))
    }

    private static func parse(_ raw: Data) -> Token? {
        var data = raw
        let text = String(decoding: raw, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        // `security -w` prints hex when the stored value isn't plain text.
        if !text.hasPrefix("{"), let decoded = Data(hexString: text) { data = decoded }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let accessToken = oauth["accessToken"] as? String, !accessToken.isEmpty
        else { return nil }
        let expiresAt = (oauth["expiresAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) }
        return Token(accessToken: accessToken, expiresAt: expiresAt)
    }
}

private extension Data {
    init?(hexString: String) {
        guard hexString.count.isMultiple(of: 2), hexString.allSatisfy(\.isHexDigit) else { return nil }
        var bytes = [UInt8]()
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}

// MARK: - API

/// The same endpoint Claude Code's `/usage` command reads. It's undocumented, so it may change.
enum UsageAPI {
    static let endpoint = URL(string: "https://api.anthropic.com/api/oauth/usage")!

    static func fetch() async throws -> UsageSnapshot {
        let token = try Credentials.load()

        var request = URLRequest(url: endpoint, timeoutInterval: 20)
        request.setValue("Bearer \(token.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("claude-usage-popup", forHTTPHeaderField: "User-Agent")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw UsageError.network(error.localizedDescription)
        }

        let http = response as? HTTPURLResponse
        switch http?.statusCode ?? 0 {
        case 200:
            return try parse(data)
        case 401, 403:
            throw UsageError.loginExpired
        case 429:
            let retryAfter = (http?.value(forHTTPHeaderField: "Retry-After")).flatMap(TimeInterval.init)
            throw UsageError.rateLimited(retryAfter: retryAfter)
        case let code:
            throw UsageError.http(code)
        }
    }

    static func parse(_ data: Data) throws -> UsageSnapshot {
        guard let raw = try? JSONDecoder().decode(RawUsage.self, from: data) else {
            throw UsageError.badResponse
        }
        var snapshot = UsageSnapshot(
            session: raw.five_hour?.meter(id: "session", label: "5h session"),
            weekly: raw.seven_day?.meter(id: "weekly", label: "Week")
        )
        for (index, limit) in (raw.limits ?? []).enumerated() {
            guard let limit, limit.kind == "weekly_scoped", let percent = limit.percent,
                  let name = limit.scope?.model?.display_name else { continue }
            snapshot.extras.append(Meter(id: "scoped-\(index)", label: "\(name) · week",
                                         percent: percent, resetsAt: parseDate(limit.resets_at)))
        }
        if snapshot.session == nil && snapshot.weekly == nil { throw UsageError.badResponse }
        return snapshot
    }

    /// Handles "2026-09-30T19:09:59.914775+00:00" and rounds to the nearest minute,
    /// so the same reset time compares equal across polls.
    static func parseDate(_ string: String?) -> Date? {
        guard var s = string else { return nil }
        if let dot = s.firstIndex(of: "."),
           let end = s[dot...].firstIndex(where: { $0 == "+" || $0 == "-" || $0 == "Z" }) {
            s.removeSubrange(dot..<end)
        }
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: s) else { return nil }
        let minute = (date.timeIntervalSinceReferenceDate / 60).rounded() * 60
        return Date(timeIntervalSinceReferenceDate: minute)
    }

    // Field names mirror the JSON, so decoding needs no custom keys.
    private struct RawUsage: Decodable {
        let five_hour: RawWindow?
        let seven_day: RawWindow?
        let limits: [RawLimit?]?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            five_hour = try? c.decodeIfPresent(RawWindow.self, forKey: .five_hour)
            seven_day = try? c.decodeIfPresent(RawWindow.self, forKey: .seven_day)
            limits = (try? c.decodeIfPresent([Lossy<RawLimit>].self, forKey: .limits))?.map(\.value)
        }
        enum CodingKeys: String, CodingKey { case five_hour, seven_day, limits }
    }

    private struct RawWindow: Decodable {
        let utilization: Double?
        let resets_at: String?

        func meter(id: String, label: String) -> Meter? {
            guard let utilization else { return nil }
            return Meter(id: id, label: label, percent: utilization, resetsAt: UsageAPI.parseDate(resets_at))
        }
    }

    private struct RawLimit: Decodable {
        let kind: String?
        let percent: Double?
        let resets_at: String?
        let scope: Scope?
        struct Scope: Decodable { let model: Model? }
        struct Model: Decodable { let display_name: String? }
    }

    /// Skips array elements that fail to decode instead of failing the whole response.
    private struct Lossy<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws { value = try? T(from: decoder) }
    }
}
