import AdjustSdk
import AdSupport
import AppTrackingTransparency
import Combine
import OSLog
import UIKit
import UserNotifications

final class OrganizerStartup: ObservableObject {
    private enum Screen {
        case loading
        case workspace
        case resource(URL)
    }

    @Published private var screen = Screen.loading

    private let cache = ResourceCache.standard
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TeacherLessonOrganizer", category: "Resources")
    private var schedule = ResourceRefreshSchedule()
    private var directoryTask: Task<Void, Never>?
    private var launchDisplayTimeout: Task<Void, Never>?
    private var preparedPermissions = false
    private var workspaceRequested = false

    var showsLaunchScreen: Bool {
        if case .workspace = screen { return false }
        return true
    }

    var page: URL? {
        if case .resource(let address) = screen { return address }
        return nil
    }

    func enterForeground() {
        schedule.enterForeground()
        updateResources()
    }

    func enterBackground() {
        schedule.enterBackground()
    }

    func registrationChanged() {
        updateResources()
    }

    func openWorkspace() {
        workspaceRequested = true
        showWorkspace()
    }

    func openResourceNotification() {
        workspaceRequested = false
        updateResources()
    }

    private var hasPendingRequest: Bool {
        schedule.hasWork(token: cache.registrationToken, hasNotification: cache.hasQueuedNotice)
    }

    private func updateResources() {
        guard directoryTask == nil, schedule.isForeground,
              !preparedPermissions || hasPendingRequest else { return }
        directoryTask = Task {
            let registration = ResourceRegistration(cache: cache)
            if !preparedPermissions {
                await registration.preparePermissions()
                preparedPermissions = true
                startDisplayTimeoutIfNeeded()
            }
            while hasPendingRequest {
                guard let request = await registration.prepareRequest() else { break }
                launchDisplayTimeout?.cancel()
                launchDisplayTimeout = nil
                let opensPage = schedule.beginRequest(
                    token: request.registrationToken, openedFromNotification: request.notice != nil
                )
                await refreshPage(with: request, opensPage: opensPage)
            }
            directoryTask = nil
        }
    }

    private func startDisplayTimeoutIfNeeded() {
        guard cache.registrationToken == nil, showsLaunchScreen, page == nil else { return }
        launchDisplayTimeout = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(15))
            } catch {
                return
            }
            guard let self, self.cache.registrationToken == nil,
                  self.showsLaunchScreen, self.page == nil else { return }
            Self.logger.notice("Still waiting for FCM registration; the resource request remains pending")
            self.showFallback()
        }
    }

    private func refreshPage(with request: ResourceRequest, opensPage: Bool) async {
        Self.logger.info("Sending resource request with FCM token; launch or push: \(opensPage)")
        do {
            let destination = try await ResourceDirectoryClient(cache: cache).destination(for: request)
            Self.logger.info("Resource response received; has destination: \(destination != nil)")
            if let destination {
                if opensPage || page == nil {
                    cache.lastPage = destination
                    if !workspaceRequested { screen = .resource(destination) }
                }
                return
            }
        } catch {
            Self.logger.error("Resource request failed: \(String(describing: error), privacy: .private)")
        }

        showFallback()
    }

    private func showFallback() {
        guard !workspaceRequested, page == nil else { return }
        if let saved = cache.lastPage {
            screen = .resource(saved)
        } else {
            showWorkspace()
        }
    }

    private func showWorkspace() {
        screen = .workspace
    }
}

private struct ResourceRegistration {
    let cache: ResourceCache

    func preparePermissions() async {
        await requestTrackingIfActive()

        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
        }
        if !UIApplication.shared.isRegisteredForRemoteNotifications {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }

    func prepareRequest() async -> ResourceRequest? {
        let allowsTracking = ATTrackingManager.trackingAuthorizationStatus == .authorized
        if allowsTracking {
            let current = await Adjust.attribution(withTimeout: 1_000)
            OrganizerAttribution.record(current, in: cache)
        } else {
            cache.campaignSnapshot = nil
        }
        let attribution = allowsTracking ? await Adjust.adid(withTimeout: 1_000) ?? "" : ""
        let advertising = allowsTracking ? ASIdentifierManager.shared().advertisingIdentifier.uuidString : ""
        guard let token = cache.registrationToken else { return nil }

        return ResourceRequest(
            campaign: allowsTracking ? cache.campaignParameters : [:],
            registrationToken: token,
            attributionID: attribution,
            advertisingID: advertising,
            hardware: UIDevice.current.model,
            notice: cache.takeNotice()
        )
    }

    private func requestTrackingIfActive() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        for _ in 0..<10 {
            if UIApplication.shared.applicationState == .active { break }
            try? await Task.sleep(for: .milliseconds(300))
        }
        if UIApplication.shared.applicationState == .active {
            _ = await Adjust.requestAppTrackingAuthorization()
        }
    }

}
