import Foundation

struct ResourceNotification {
    let identifier: String?
}

final class ResourceCache {
    static let standard = ResourceCache(defaults: .standard)
    static let noticeSelected = Notification.Name("teacherLessonOrganizer.resources.noticeSelected")

    private enum Field: String {
        case installation, client, directory, page, registration, messagingProject, campaign, queuedNotice

        var key: String { "teacherLessonOrganizer.resources." + rawValue }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    lazy private(set) var installationIdentifier = identifier(in: .installation)
    lazy private(set) var clientIdentifier = identifier(in: .client)

    var directory: URL? {
        get { ResourceDirectory.address(self[.directory]) }
        set { self[.directory] = newValue?.absoluteString }
    }

    var lastPage: URL? {
        get { ResourceDirectory.address(self[.page]) }
        set { self[.page] = newValue?.absoluteString }
    }

    var registrationToken: String? {
        get { self[.registration] }
        set { self[.registration] = newValue }
    }

    var campaignSnapshot: String? {
        get { self[.campaign] }
        set { self[.campaign] = newValue }
    }

    var hasQueuedNotice: Bool { self[.queuedNotice] != nil }

    var campaignParameters: [String: Any] {
        guard let snapshot = campaignSnapshot,
              let values = try? JSONSerialization.jsonObject(with: Data(snapshot.utf8)) as? [String: Any] else { return [:] }

        let fields = ["trackerToken", "trackerName", "network", "campaign", "adgroup", "creative",
                      "clickLabel", "costType", "costCurrency"]
        var campaign: [String: Any] = [
            "costAmount": values["costAmount"] as? Double ?? 0,
            "jsonResponse": snapshot
        ]
        for field in fields {
            campaign[field] = values[field] as? String ?? ""
        }
        return campaign
    }

    func useMessagingProject(_ identifier: String) {
        guard self[.messagingProject] != identifier else { return }
        self[.messagingProject] = identifier
        registrationToken = nil
    }

    func enqueueNotice(identifier: String?) {
        self[.queuedNotice] = identifier ?? ""
    }

    func takeNotice() -> ResourceNotification? {
        guard let queued = self[.queuedNotice] else { return nil }
        self[.queuedNotice] = nil
        return ResourceNotification(identifier: queued.isEmpty ? nil : queued)
    }

    private subscript(field: Field) -> String? {
        get { defaults.string(forKey: field.key) }
        set { defaults.set(newValue, forKey: field.key) }
    }

    private func identifier(in field: Field) -> String {
        if let saved = self[field], UUID(uuidString: saved) != nil { return saved }
        let generated = UUID().uuidString.lowercased()
        self[field] = generated
        return generated
    }
}
