struct ResourceRefreshSchedule {
    private(set) var isForeground = false
    private var needsSession = false
    private var lastAttemptedToken: String?

    mutating func enterForeground() {
        guard !isForeground else { return }
        isForeground = true
        needsSession = true
    }

    mutating func enterBackground() {
        isForeground = false
    }

    func hasWork(token: String?, hasNotification: Bool) -> Bool {
        guard isForeground, let token else { return false }
        let needsTokenDelivery = lastAttemptedToken.map { $0 != token } ?? false
        return needsSession || hasNotification || needsTokenDelivery
    }

    mutating func beginRequest(token: String, openedFromNotification: Bool) -> Bool {
        let opensPage = needsSession || openedFromNotification
        needsSession = false
        lastAttemptedToken = token
        return opensPage
    }
}
